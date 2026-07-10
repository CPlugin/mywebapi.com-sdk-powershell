function Register-MT5Realtime {
    <#
    .SYNOPSIS
        Subscribes an MT5 real-time connection to one or more event categories.
    .DESCRIPTION
        The MT5 hub exposes margin-call updates as a server stream; connection-status events are
        delivered automatically after Connect-MT5Realtime. All events surface through Receive-MT5Realtime.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [Parameter(Mandatory)][ValidateSet('MarginCall')][string[]] $Category
    )
    foreach ($c in $Category) {
        switch ($c) {
            'MarginCall' { $Connection.Sink.StartStream('StreamMarginCallUpdates') }
        }
    }
}
