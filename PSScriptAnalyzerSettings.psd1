@{
    Severity = @('Error', 'Warning')
    # Generated cmdlets legitimately use plural nouns matching the API (e.g. Get-MT4GroupsGet).
    ExcludeRules = @('PSUseSingularNouns')
}
