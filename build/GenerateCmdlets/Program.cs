using System.Text;
using System.Text.Json;

// Args: <spec-path> <output-root>  (output-root = src/MyWebApi)
string specPath = args.Length > 0 ? args[0] : "spec/v2.json";
string outRoot  = args.Length > 1 ? args[1] : "src/MyWebApi";

var verbMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
    ["get"] = "Get", ["post"] = "Invoke", ["patch"] = "Update", ["put"] = "Set", ["delete"] = "Remove",
};
// PowerShell reserves these common-parameter names (several come from SupportsShouldProcess,
// which every mutating cmdlet declares). A query param whose PascalCased name collides -- e.g.
// "confirm" on SrvRestart colliding with -Confirm -- gets a "Query" suffix on the cmdlet
// parameter only; the wire key sent to the API stays the original OpenAPI name.
var reservedParamNames = new HashSet<string>(StringComparer.Ordinal) {
    "Confirm", "Verbose", "Debug", "WhatIf", "ErrorAction", "WarningAction", "InformationAction",
    "ErrorVariable", "WarningVariable", "InformationVariable", "OutVariable", "OutBuffer",
    "PipelineVariable", "ProgressAction",
};
// HTTP methods OpenAPI allows in a path item that we intentionally do not map to a cmdlet verb.
// Anything else under a path item (e.g. a shared "parameters" array) is not an HTTP method at all
// and must stay silent -- only genuine-but-unmapped *operations* get a warning ("no silent drops").
var knownUnmappedMethods = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "head", "options", "trace" };

using var doc = JsonDocument.Parse(File.ReadAllText(specPath));
var paths = doc.RootElement.GetProperty("paths");
var exported = new List<string>();
int emitted = 0;
int warnings = 0;

// * Pass 1: collect every mappable operation before naming anything. A handful of routes share
//   an action segment between a "bare" variant and a variant with one extra trailing path
//   parameter (e.g. TradesGet vs. TradesGet/{ticket}) -- both are real, distinct operations and
//   each needs its own cmdlet/file. Naming them correctly requires seeing the whole group at once
//   (see pass 2) rather than reacting to whichever happens to appear first/second in the spec.
var collected = new List<(string Route, string Method, string Verb, string Platform, string Action,
    List<string> PathParams, JsonElement Op, string BaseName)>();

foreach (var pathProp in paths.EnumerateObject())
{
    string route = pathProp.Name;
    foreach (var methodProp in pathProp.Value.EnumerateObject())
    {
        string method = methodProp.Name;
        if (!verbMap.TryGetValue(method, out var verb))
        {
            // * No silent drops: warn on any recognizable-but-unmapped HTTP operation so a future
            //   PUT/DELETE/etc. added to the spec doesn't vanish from the generated module unnoticed.
            //   Non-method path-item keys (e.g. "parameters") are not operations and stay silent.
            if (knownUnmappedMethods.Contains(method) || methodProp.Value.ValueKind == JsonValueKind.Object)
            {
                Console.Error.WriteLine($"warning: unmapped HTTP method '{method}' on '{route}' -- no cmdlet generated");
                warnings++;
            }
            continue;
        }
        var op = methodProp.Value;

        string platform = route.Contains("/MT5/") ? "MT5" : "MT4";
        var segs = route.Split('/', StringSplitOptions.RemoveEmptyEntries)
                        .Where(s => !s.StartsWith('{')).ToArray();
        string action = segs[^1];

        // Path parameters -> mandatory string params (except tradePlatform, which is optional w/ fallback).
        var pathParams = System.Text.RegularExpressions.Regex.Matches(route, "{(.*?)}")
            .Select(m => m.Groups[1].Value).ToList();

        string baseName = $"{verb}-{platform}{action}";
        collected.Add((route, method, verb, platform, action, pathParams, op, baseName));
    }
}

// * Pass 2: assign final, unique cmdlet names. Within a colliding group, the variant with the
//   fewest path parameters (typically just {tradePlatform} -- a bulk/list-style operation) keeps
//   the plain name; the more specific variant(s) get "By<ExtraParam>" appended, using whichever
//   path parameter(s) the plain variant doesn't have. This mirrors literal action names already
//   present in the spec (e.g. TradesGetByLogin, TradesGetBySymbol) instead of an arbitrary suffix
//   that depends on JSON document order.
var finalNames = new Dictionary<int, string>();
foreach (var group in collected.Select((entry, idx) => (entry, idx)).GroupBy(x => x.entry.BaseName))
{
    var members = group.OrderBy(x => x.entry.PathParams.Count).ToList();
    var basePathParams = members[0].entry.PathParams;
    for (int i = 0; i < members.Count; i++)
    {
        var (entry, idx) = members[i];
        if (i == 0) { finalNames[idx] = entry.BaseName; continue; }

        var extraParams = entry.PathParams.Except(basePathParams).ToList();
        string candidate = extraParams.Count > 0
            ? $"{entry.BaseName}By{string.Concat(extraParams.Select(Pascal))}"
            : $"{entry.BaseName}{i + 1}";
        if (finalNames.Values.Contains(candidate))
        {
            Console.Error.WriteLine($"warning: could not disambiguate duplicate cmdlet name '{entry.BaseName}' for '{entry.Route}' -- skipping");
            warnings++;
            continue;
        }
        finalNames[idx] = candidate;
    }
}

for (int idx = 0; idx < collected.Count; idx++)
{
    if (!finalNames.TryGetValue(idx, out var funcName)) continue; // dropped: unresolvable duplicate (warned above)
    var (route, method, verb, platform, action, pathParams, op, _) = collected[idx];

    {
        bool isMutating = method is "post" or "patch" or "put" or "delete";
        var tags = op.TryGetProperty("tags", out var t) && t.ValueKind == JsonValueKind.Array
            ? t.EnumerateArray().Select(x => x.GetString() ?? "").ToArray() : Array.Empty<string>();
        bool destructive = tags.Any(x => x.Contains("(destructive)"));
        string summary = op.TryGetProperty("summary", out var s) ? (s.GetString() ?? "") : "";

        var sb = new StringBuilder();
        sb.AppendLine($"function {funcName} {{");
        sb.AppendLine("    <#");
        sb.AppendLine($"    .SYNOPSIS");
        sb.AppendLine($"        {EscapeHelp(string.IsNullOrWhiteSpace(summary) ? funcName : summary)}");
        sb.AppendLine("    #>");

        string cmdletBinding = isMutating
            ? (destructive ? "[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]"
                           : "[CmdletBinding(SupportsShouldProcess)]")
            : "[CmdletBinding()]";
        sb.AppendLine($"    {cmdletBinding}");

        // * Query params (op.parameters where in == "query"). Each becomes its own optional
        //   cmdlet parameter, PascalCased from the OpenAPI name; the ORIGINAL wire name is kept
        //   as the query key when the request is built below. Reserved cmdlet-parameter names
        //   (see reservedParamNames above) get a "Query" suffix so they don't collide with
        //   PowerShell's own common parameters.
        var queryParams = new List<(string WireName, string ParamName, string TypeAnnotation, bool IsSwitch)>();
        if (op.TryGetProperty("parameters", out var opParamsEl) && opParamsEl.ValueKind == JsonValueKind.Array)
        {
            foreach (var p in opParamsEl.EnumerateArray())
            {
                if (!p.TryGetProperty("in", out var inEl) || inEl.GetString() != "query") continue;
                string wireName = p.GetProperty("name").GetString() ?? "";
                var schema = p.TryGetProperty("schema", out var schemaEl) ? schemaEl : default;
                var (typeAnnotation, isSwitch) = MapQueryParamType(schema);
                string pascalName = Pascal(wireName);
                string paramName = reservedParamNames.Contains(pascalName) ? pascalName + "Query" : pascalName;
                queryParams.Add((wireName, paramName, typeAnnotation, isSwitch));
            }
        }
        // Cursor-paged endpoints (both "limit" and "cursor" query params) also get -All, which
        // tells Invoke-MyWebApiRequest to follow the cursor and return every page concatenated.
        bool isPaged = queryParams.Any(q => q.WireName == "limit") && queryParams.Any(q => q.WireName == "cursor");

        sb.AppendLine("    param(");
        var paramLines = new List<string>();
        paramLines.Add("        [Parameter()][object] $Connection");
        foreach (var pp in pathParams)
        {
            if (pp == "tradePlatform")
                paramLines.Add("        [Parameter()][string] $TradePlatform");
            else
                paramLines.Add($"        [Parameter(Mandatory)][string] ${Pascal(pp)}");
        }
        foreach (var q in queryParams)
        {
            paramLines.Add($"        [Parameter()]{q.TypeAnnotation} ${q.ParamName}");
        }
        if (isPaged) paramLines.Add("        [Parameter()][switch] $All");
        // Body param for mutating ops.
        if (isMutating) paramLines.Add("        [Parameter()][object] $Body");
        // Common params.
        paramLines.Add("        [Parameter()][Nullable[guid]] $CacheId");
        paramLines.Add("        [Parameter()][int] $CacheTimeout");
        paramLines.Add("        [Parameter()][string] $IdempotencyKey");
        sb.AppendLine(string.Join(",\n", paramLines));
        sb.AppendLine("    )");

        // Build the runtime path with param substitution.
        string runtimePath = route;
        foreach (var pp in pathParams)
        {
            if (pp == "tradePlatform") continue; // handled by the pipeline
            runtimePath = runtimePath.Replace("{" + pp + "}", "$(" + $"[uri]::EscapeDataString([string]${Pascal(pp)})" + ")");
        }

        if (isMutating)
        {
            sb.AppendLine($"    if (-not $PSCmdlet.ShouldProcess('{platform}/{action}')) {{ return }}");
        }
        if (queryParams.Count > 0)
        {
            sb.AppendLine("    $q = @{}");
            foreach (var q in queryParams)
            {
                sb.AppendLine(q.IsSwitch
                    ? $"    if (${q.ParamName}) {{ $q['{q.WireName}'] = 'true' }}"
                    : $"    if ($PSBoundParameters.ContainsKey('{q.ParamName}')) {{ $q['{q.WireName}'] = ${q.ParamName} }}");
            }
        }
        sb.Append($"    $reqArgs = @{{ Method = '{verb switch { "Get" => "Get", "Invoke" => "Post", "Update" => "Patch", "Set" => "Put", "Remove" => "Delete", _ => "Get" }}'; ");
        sb.Append($"Path = \"{runtimePath}\"");
        if (pathParams.Contains("tradePlatform")) sb.Append("; TradePlatform = $TradePlatform");
        if (queryParams.Count > 0) sb.Append("; Query = $q");
        if (isMutating) sb.Append("; Body = $Body");
        sb.AppendLine(" }");
        if (isPaged) sb.AppendLine("    if ($All) { $reqArgs.All = $true }");
        sb.AppendLine("    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }");
        sb.AppendLine("    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }");
        sb.AppendLine("    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }");
        sb.AppendLine("    Invoke-MyWebApiRequest -Connection $Connection @reqArgs");
        sb.AppendLine("}");

        string dir = Path.Combine(outRoot, "Public", platform);
        Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir, funcName + ".ps1"), sb.ToString());
        exported.Add(funcName);
        emitted++;
    }
}

// Emit the export list for the manifest.
var exportList = "@(\n" + string.Join(",\n", exported.OrderBy(x => x).Select(x => $"    '{x}'")) + "\n)\n";
File.WriteAllText(Path.Combine(outRoot, "generated-exports.psd1"), exportList);
Console.WriteLine($"Generated {emitted} cmdlets.");
if (warnings > 0) Console.WriteLine($"({warnings} warning(s) -- see stderr)");

static string Pascal(string s) => string.IsNullOrEmpty(s) ? s : char.ToUpperInvariant(s[0]) + s[1..];
static string EscapeHelp(string s) => s.Replace("#>", "# >");

// Maps an OpenAPI query-parameter schema to a PowerShell type annotation (incl. brackets) and
// whether it should be a [switch] rather than a bound value. Anything without a recognizable
// "type" (plain string, date-time strings, $ref/allOf enums, or a missing schema) falls back to
// [string] -- the wire value is always sent as text regardless of the PowerShell-side type.
static (string TypeAnnotation, bool IsSwitch) MapQueryParamType(JsonElement schema)
{
    if (schema.ValueKind != JsonValueKind.Object) return ("[string]", false);
    string? type = schema.TryGetProperty("type", out var t) ? t.GetString() : null;
    string? format = schema.TryGetProperty("format", out var f) ? f.GetString() : null;

    if (type == "array")
    {
        string elem = "string";
        if (schema.TryGetProperty("items", out var items) && items.ValueKind == JsonValueKind.Object)
        {
            string? itemType = items.TryGetProperty("type", out var it) ? it.GetString() : null;
            string? itemFormat = items.TryGetProperty("format", out var itf) ? itf.GetString() : null;
            if (itemType == "integer") elem = itemFormat == "int64" ? "long" : "int";
        }
        return ($"[{elem}[]]", false);
    }

    return type switch
    {
        "integer" => (format == "int64" ? "[long]" : "[int]", false),
        "number" => ("[double]", false),
        "boolean" => ("[switch]", true),
        _ => ("[string]", false),
    };
}
