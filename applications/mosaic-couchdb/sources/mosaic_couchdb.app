
{application, mosaic_couchdb, [
	{description, "mOSAIC couchdb component"},
	{vsn, "1"},
	{applications, [kernel, stdlib, mosaic_component, couch]},
	{modules, []},
	{registered, []},
	{mod, {mosaic_dummy_app, defaults}},
	{env, []}
]}.
