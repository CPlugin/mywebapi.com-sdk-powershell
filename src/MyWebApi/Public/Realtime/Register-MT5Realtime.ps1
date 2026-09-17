function Register-MT5Realtime {
    <#
    .SYNOPSIS
        Subscribes an MT5 real-time connection to one or more event categories.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [Parameter(Mandatory)][ValidateSet('MarginCall')][string[]] $Category
    )
    if ($Connection.Sink.HasFault) { throw "Realtime connection fault: $($Connection.Sink.Fault.Message)" }
    foreach ($c in $Category) {
        switch ($c) {
            'MarginCall' { $Connection.Sink.StartStream('StreamMarginCallUpdates') }
        }
    }
}
