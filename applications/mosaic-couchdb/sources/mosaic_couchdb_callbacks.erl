
-module (mosaic_couchdb_callbacks).

-behaviour (mosaic_component_callbacks).


-export ([configure/0, standalone/0]).
-export ([init/0, terminate/2, handle_call/5, handle_cast/4, handle_info/2]).


-import (mosaic_enforcements, [enforce_ok/1, enforce_ok_1/1, enforce_ok_2/1]).


-record (state, {status, identifier, group, socket}).


init () ->
	try
		State = #state{
					status = waiting_initialize,
					identifier = none, group = none,
					socket = none},
		erlang:self () ! {mosaic_couchdb_callbacks_internals, trigger_initialize},
		{ok, State}
	catch throw : {error, Reason} -> {stop, Reason} end.


terminate (_Reason, _State = #state{}) ->
	ok = stop_applications_async (),
	ok.


handle_call (<<"mosaic-couchdb:get-endpoint">>, null, <<>>, _Sender, State = #state{status = executing, socket = Socket}) ->
	{SocketIp, SocketPort, SocketFqdn} = Socket,
	Outcome = {ok, {struct, [
					{<<"ip">>, SocketIp}, {<<"port">>, SocketPort}, {<<"fqdn">>, SocketFqdn},
					{<<"url">>, erlang:iolist_to_binary (["http://", SocketFqdn, ":", erlang:integer_to_list (SocketPort), "/"])}
				]}, <<>>},
	{reply, Outcome, State};
	
handle_call (<<"mosaic-couchdb:get-node-identifier">>, null, <<>>, _Sender, State) ->
	Outcome = {ok, erlang:atom_to_binary (erlang:node (), utf8), <<>>},
	{reply, Outcome, State};
	
handle_call (Operation, Inputs, _Data, _Sender, State = #state{status = executing}) ->
	ok = mosaic_transcript:trace_error ("received invalid call request; ignoring!", [{operation, Operation}, {inputs, Inputs}]),
	{reply, {error, {invalid_operation, Operation}}, State};
	
handle_call (Operation, Inputs, _Data, _Sender, State = #state{status = Status})
		when (Status =/= executing) ->
	ok = mosaic_transcript:trace_error ("received invalid call request; ignoring!", [{operation, Operation}, {inputs, Inputs}, {status, Status}]),
	{reply, {error, {invalid_status, Status}}, State}.


handle_cast (Operation, Inputs, _Data, State = #state{status = executing}) ->
	ok = mosaic_transcript:trace_error ("received invalid cast request; ignoring!", [{operation, Operation}, {inputs, Inputs}]),
	{noreply, State};
	
handle_cast (Operation, Inputs, _Data, State = #state{status = Status})
		when (Status =/= executing) ->
	ok = mosaic_transcript:trace_error ("received invalid cast request; ignoring!", [{operation, Operation}, {inputs, Inputs}, {status, Status}]),
	{noreply, State}.


handle_info ({mosaic_couchdb_callbacks_internals, trigger_initialize}, OldState = #state{status = waiting_initialize}) ->
	try
		Identifier = enforce_ok_1 (mosaic_generic_coders:application_env_get (identifier, mosaic_couchdb,
					{decode, fun mosaic_component_coders:decode_component/1}, {error, missing_identifier})),
		Group = enforce_ok_1 (mosaic_generic_coders:application_env_get (group, mosaic_couchdb,
					{decode, fun mosaic_component_coders:decode_group/1}, {error, missing_group})),
		ok = enforce_ok (mosaic_component_callbacks:acquire_async (
					[{<<"socket">>, <<"socket:ipv4:tcp">>}],
					{mosaic_couchdb_callbacks_internals, acquire_return})),
		NewState = OldState#state{status = waiting_acquire_return, identifier = Identifier, group = Group},
		{noreply, NewState}
	catch throw : Error = {error, _Reason} -> {stop, Error, OldState} end;
	
handle_info ({{mosaic_couchdb_callbacks_internals, acquire_return}, Outcome}, OldState = #state{status = waiting_acquire_return, identifier = Identifier, group = Group}) ->
	try
		Descriptors = enforce_ok_1 (Outcome),
		[Socket] = enforce_ok_1 (mosaic_component_coders:decode_socket_ipv4_tcp_descriptors (
					[<<"socket">>], Descriptors)),
		ok = enforce_ok (setup_applications (Identifier, Socket)),
		ok = enforce_ok (start_applications ()),
		ok = enforce_ok (mosaic_component_callbacks:register_async (Group, {mosaic_couchdb_callbacks_internals, register_return})),
		NewState = OldState#state{status = waiting_register_return, socket = Socket},
		{noreply, NewState}
	catch throw : Error = {error, _Reason} -> {stop, Error, OldState} end;
	
handle_info ({{mosaic_couchdb_callbacks_internals, register_return}, Outcome}, OldState = #state{status = waiting_register_return}) ->
	try
		ok = enforce_ok (Outcome),
		NewState = OldState#state{status = executing},
		{noreply, NewState}
	catch throw : Error = {error, _Reason} -> {stop, Error, OldState} end;
	
handle_info (Message, State = #state{status = Status}) ->
	ok = mosaic_transcript:trace_error ("received invalid message; terminating!", [{message, Message}, {status, Status}]),
	{stop, {error, {invalid_message, Message}}, State}.


standalone () ->
	mosaic_application_tools:boot (fun standalone_1/0).

standalone_1 () ->
	try
		ok = enforce_ok (load_applications ()),
		ok = enforce_ok (mosaic_component_callbacks:configure ([{identifier, mosaic_couchdb}])),
		Identifier = enforce_ok_1 (mosaic_generic_coders:application_env_get (identifier, mosaic_couchdb,
					{decode, fun mosaic_component_coders:decode_component/1}, {error, missing_identifier})),
		Socket = {<<"0.0.0.0">>, 27742, <<"127.0.0.1">>},
		ok = enforce_ok (setup_applications (Identifier, Socket)),
		ok = enforce_ok (start_applications ()),
		ok
	catch throw : Error = {error, _Reason} -> Error end.


configure () ->
	try
		ok = enforce_ok (load_applications ()),
		ok = enforce_ok (mosaic_component_callbacks:configure ([
					{identifier, mosaic_couchdb},
					{group, mosaic_couchdb},
					harness])),
		ok
	catch throw : Error = {error, _Reason} -> Error end.


resolve_applications () ->
	{ok, [
			sasl, os_mon, inets, crypto,
			public_key, ssl, ibrowse, mochiweb,
			couch]}.


load_applications () ->
	try
		ok = enforce_ok (mosaic_application_tools:load (mosaic_couchdb, without_dependencies)),
		Applications = enforce_ok_1 (resolve_applications ()),
		ok = enforce_ok (mosaic_application_tools:load (Applications, without_dependencies)),
		ok
	catch throw : Error = {error, _Reason} -> Error end.


setup_applications (Identifier, Socket) ->
	try
		IdentifierString = enforce_ok_1 (mosaic_component_coders:encode_component (Identifier)),
		{SocketIp, SocketPort, SocketFqdn} = Socket,
		SocketFqdnString = erlang:binary_to_list (SocketFqdn),
		SocketIpString = erlang:binary_to_list (SocketIp),
		SocketPortString = erlang:integer_to_list (SocketPort),
		InitValues = [
				{{"httpd", "bind_address"}, SocketIpString},
				{{"httpd", "port"}, SocketPortString}],
		ok = enforce_ok (mosaic_component_callbacks:configure ([
				{env, couch, ini_values, InitValues}])),
		ok = error_logger:info_report (["Configuring mOSAIC CouchDB component...",
					{identifier, IdentifierString},
					{url, erlang:list_to_binary ("http://" ++ SocketFqdnString ++ ":" ++ erlang:integer_to_list (SocketPort) ++ "/")},
					{endpoint, Socket}]),
		ok
	catch throw : Error = {error, _Reason} -> Error end.


start_applications () ->
	try
		Applications = enforce_ok_1 (resolve_applications ()),
		ok = enforce_ok (mosaic_application_tools:start (Applications, without_dependencies)),
		ok
	catch throw : Error = {error, _Reason} -> Error end.


stop_applications () ->
	_ = init:stop ().


stop_applications_async () ->
	_ = erlang:spawn (
				fun () ->
					ok = timer:sleep (100),
					ok = stop_applications (),
					ok
				end),
	ok.
