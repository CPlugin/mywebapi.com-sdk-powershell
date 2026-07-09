# * The session context is a single module-scoped hashtable. Kept as a hashtable
#   (not a class) so InModuleScope tests can inspect it without type coupling.
$script:MyWebApiContext = $null
