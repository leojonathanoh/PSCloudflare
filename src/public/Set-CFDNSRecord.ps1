function Set-CFDNSRecord {
        <#
        .SYNOPSIS
        Modifies a cloudflare dns record.
        .DESCRIPTION
        Modifies a cloudflare dns record.
        .PARAMETER ZoneID
        You apply dns records to individual zones or to the whole organization. If you pass ZoneID it will be targeted otherwise the currently loaded zone from Set-CFCurrentZone is targeted.
        .PARAMETER RecordType
        Type of record to modify.
        .PARAMETER ID
        The dns record ID you would like to modify. If not defined it will be derived from the Name and RecordType parameters.
        .PARAMETER Name
        name of the record to modify.
        .PARAMETER Content
        DNS record value write.
        .PARAMETER TTL
        Time to live, optional update setting. Default is 120.
        .Parameter Proxied
        Set or unset orange cloud mode for a record. Optional.
        .EXAMPLE
        TBD
        .LINK
        https://github.com/zloeber/PSCloudFlare
        .NOTES
        Author: Zachary Loeber
        #>
        [CmdletBinding()]
        Param (
            [Parameter()]
            [ValidateScript({ IsNullOrCFID $_ })]
            [String]$ZoneID,

            [Parameter(ValueFromPipelineByPropertyName=$true)]
            [ValidateScript({ IsCFID $_ })]
            [String]$ID,

            [Parameter()]
            [CFDNSRecordType]$RecordType,

            [Parameter()]
            [String]$Name,

            [Parameter()]
            [String]$Content,

            [Parameter()]
            [ValidateRange(120,2147483647)]
            [int]$TTL,

            [Parameter()]
            [CFDNSOrangeCloudMode]$Proxied
        )
        begin {
            if ($script:ThisModuleLoaded -eq $true) {
                Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
            }
            $FunctionName = $MyInvocation.MyCommand.Name
            Write-Verbose "$($FunctionName): Begin."

            # If the ZoneID is empty see if we have loaded one earlier in the module and use it instead.
            if ([string]::IsNullOrEmpty($ZoneID) -and ($null -ne $Script:ZoneID)) {
                Write-Verbose "$($FunctionName): No ZoneID was passed but the current targeted zone was $($Script:ZoneName) so this will be used."
                $ZoneID = $Script:ZoneID
            }
            elseif ([string]::IsNullOrEmpty($ZoneID)) {
                throw 'No Zone was set or passed!'
            }

            $Data = @{
                type = $RecordType.ToString()
                name = $Name
                content = $Content
            }
            <# Logic used here:
                - If DNS CF ID is passed fill in Name, RecordType, and Content if they are null
                - If no DNS CF ID is passed, first get the ID if possible and then fill in name or content if they are null
            #>

            #        -or ([string]::IsNullOrEmpty($Content)) -or ([string]::IsNullOrEmpty($Name)) )
            if ([string]::IsNullOrEmpty($ID)) {
                Write-Verbose "$($FunctionName): No DNS record ID was passed. Attempting to retrieve the record ID based on the record name and type passed to this function"
                try {
                    $DNSRecord = Get-CFDNSRecord -ZoneID $ZoneID -RecordType $RecordType -Name $Name
                }
                catch {
                    throw
                }

                $DNSRecordID = $DNSRecord.id
            }
            else {
                $DNSRecord = Get-CFDNSRecord -ZoneID $ZoneID -ID $ID
                $DNSRecordID = $ID
            }

            if ([string]::IsNullOrEmpty($Content)) {
                $Content = $DNSRecord.Content
            }
            if ([string]::IsNullOrEmpty($Name)) {
                $Name = $DNSRecord.Name
            }
            if ($null -eq $RecordType) {
                $RecordType = $DNSRecord.type
            }

            switch ($Proxied) {
                'on' {
                    $Data.proxied = $true
                }
                'off' {
                    $Data.proxied = $false
                }
            }

            if (($null -ne $TTL) -and ($TTL -ne 0)) {
                $Data.ttl = $TTL
            }

        }
        end {
            # Construct the URI for this package
            $Uri = $Script:APIURI + ('/zones/{0}/dns_records/{1}' -f $ZoneID,$DNSRecordID)
            Write-Verbose "$($FunctionName): URI = '$Uri'"

            try {
                Set-CFRequestData -Uri $Uri -Body $Data -Method 'Put'
                $Response = Invoke-CFAPI4Request -ErrorAction Stop
            }
            catch {
                Throw $_
            }

            Write-Verbose "$($FunctionName): End."
        }
    }