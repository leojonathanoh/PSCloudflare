﻿Function Get-CFDNSRecord {
    <#
    .SYNOPSIS
    List Cloudflare page rules.
    .DESCRIPTION
    List Cloudflare page rules.
    .PARAMETER ZoneID
    If you pass ZoneID it will be targeted otherwise the currently loaded zone from Set-CFCurrentZone is targeted.
    .PARAMETER ID
    A Cloudflare ID for the record.
    .PARAMETER RecordType
    Record type to retrieve. If no value is passed all types will be enumerated.
    .PARAMETER Name
    DNS record name. If not passed then all records will be returned.
    .PARAMETER Order
    Order the results by type, name, content, ttl, or proxied. Default is name.
    .PARAMETER Direction
    Return results in asc (ascending) or dec (decending) order. Default is asc.
    .PARAMETER MatchScope
    Match either 'any' or 'all' the supplied matching parameters passed to this function. Default is all.
    .PARAMETER PerPage
    Maximum results returned per page. Default is 50.
    .EXAMPLE
    PS> Get-CFDNSRecord

    Shows all DNS records in the current zone
    .NOTES
    Author: Zachary Loeber
    .LINK
    https://github.com/zloeber/PSCloudFlare
    #>

    [CmdletBinding()]
    Param (
        [Parameter()]
        [ValidateScript({
            IsNullOrCFID $_
        })]
        [String]$ZoneID,

        [Parameter()]
        [ValidateScript({ IsCFID $_ })]
        [String]$ID,

        [Parameter()]
        [CFDNSRecordType]$RecordType,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$PerPage = 50,

        [Parameter()]
        [ValidateSet('type', 'name', 'content', 'ttl', 'proxied')]
        [string]$Order = 'name',

        [Parameter()]
        [ValidateSet( 'asc', 'dec' )]
        [string]$Direction = 'asc',

        [Parameter()]
        [ValidateSet( 'any', 'all' )]
        [string]$MatchScope = 'all'
    )

    $FunctionName = $MyInvocation.MyCommand.Name

    # If the ZoneID is empty see if we have loaded one earlier in the module and use it instead.
    if ([string]::IsNullOrEmpty($ZoneID) -and ($null -ne $Script:ZoneID)) {
        Write-Verbose "$($FunctionName): No ZoneID was passed but the current targeted zone was $($Script:ZoneName) so this will be used."
        $ZoneID = $Script:ZoneID
    }
    elseif ([string]::IsNullOrEmpty($ZoneID)) {
        throw 'No Zone was set or passed!'
    }

    $Data = @{
        'direction' = $Direction
        'match' = $MatchScope
        'order' = $Order
        'per_page' = $PerPage
    }

    if (-not [string]::IsNullOrEmpty($ID)) {
        # If we passed a CF ID then get the record associated with it.
        $Uri = $Script:APIURI + ('/zones/{0}/dns_records/{1}' -f $ZoneID,$ID)

        Write-Verbose "$($FunctionName): Requesting DNS record information for CF ID - $ID"
        Set-CFRequestData -Uri $Uri
        return (Invoke-CFAPI4Request -ErrorAction Stop).result
    }
    # If no record type was passed then try to get them all by type
    elseif ($null -eq [CFDNSRecordType]::$RecordType) {
        $PassedParams = $PsCmdlet.MyInvocation.BoundParameters
        [enum]::getnames([CFDNSRecordType]) | ForEach {
            Write-Verbose "$($Functionname): Attempting to retreive DNS records of type - $($_)"
            Get-CFDNSRecord @PassedParams -RecordType $_
            return # Return here so we don't over process
        }
    }
    else {
        $Data.type = $RecordType.ToString()
        if (-not [string]::IsNullOrEmpty($Name)) {
            Write-Verbose "$($Functionname): Looking for $RecordType DNS name $Name"
            $Data.name = $Name
        }
        $Uri = $Script:APIURI + ('/zones/{0}/dns_records' -f $ZoneID)
    }

    if (-not [string]::IsNullOrEmpty($Uri)) {
        # Always start at the first page
        $Data.page = 1

        # Get the first page, from there we will be able to see the total page numbers
        try {
            Write-Verbose "$($FunctionName): Returning the first result"
            Set-CFRequestData -Uri $Uri -Body $Data
            $LatestPage = Invoke-CFAPI4Request -ErrorAction Stop
            $LatestPage.result
            $TotalPages = $LatestPage.result_info.total_pages
        }
        catch {
            throw $_
        }

        $PageNumber = 2

        # Get any more pages
        while ($PageNumber -le $TotalPages) {
            try {
                Write-Verbose "$($FunctionName): Returning $PageNumber of $TotalPages"
                $Data.page = $PageNumber
                Set-CFRequestData -Uri $Uri -Body $Data
                (Invoke-CFAPI4Request -ErrorAction Stop).result
                $PageNumber++
            }
            catch {
                throw $_
                break
            }
        }
    }
}