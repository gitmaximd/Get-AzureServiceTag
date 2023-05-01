Param(
    [CmdletBinding()]

    # The Application (client) ID for the application registered in Azure AD.
    [Parameter(Mandatory = $true)]
    [guid]
    $ApplicationId,

    # The Directory (tenant) ID for the application registered in Azure AD.
    [Parameter(Mandatory = $true)]
    [guid]
    $TenantId,

    # The Value of the client secret for the application registered in Azure AD.
    [Parameter(Mandatory = $true)]
    [string]
    $ClientSecret,

    # The location that will be used as a reference for version (not as a filter based on location, you will get the list of service tags with prefix details across all regions but limited to the cloud.
    [Parameter(Mandatory = $true)]
    [string]
    $Location,

    # The subscription credentials which uniquely identify the Microsoft Azure subscription. The subscription ID forms part of the URI for every service call.
    [Parameter(Mandatory = $true)]
    [guid]
    $SubscriptionId,

    # Service Tag name. Refer to https://learn.microsoft.com/en-us/azure/virtual-network/service-tags-overview#available-service-tags
    [Parameter(Mandatory = $true)]
    [string]
    $ServiceTag
)

function Get-AzureADToken {
    [CmdletBinding()]
    param (
        # The Application (client) ID for the application registered in Azure AD.
        [Parameter(Mandatory = $true)]
        [guid]
        $ApplicationId,

        # The Directory (tenant) ID for the application registered in Azure AD.
        [Parameter(Mandatory = $true)]
        [guid]
        $TenantId,

        # The Value of the client secret for the application registered in Azure AD.
        [Parameter(Mandatory = $true)]
        [string]
        $ClientSecret
    )
    
    $azureAdEndpoint = [uri]"https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $body = @{
        client_id     = $ApplicationId
        grant_type    = 'client_credentials'
        scope         = 'https://management.azure.com//.default' # When you request a token for https://management.azure.com/ and use .default, you must request https://management.azure.com//.default (notice the double slash!). 
        client_secret = $ClientSecret
   }
    $params = @{
        Uri    = $azureAdEndpoint
        Method = 'Post'
        Body   = $body
    }
    $result = Invoke-WebRequest -Uri $azureAdEndpoint -Method Post -Body $body

    if($result.StatusCode -eq 200) {
        $token = ($result.Content | ConvertFrom-Json).access_token
        return $token
    }
    else {
        Write-Output ("Failed retrieving the access token. Exception: {0}" -f $result.StatusDescription)
    }
}

function Get-AzureServiceTag {
    [CmdletBinding()]
    param (
        # The subscription credentials which uniquely identify the Microsoft Azure subscription. The subscription ID forms part of the URI for every service call.
        [Parameter(Mandatory = $true)]
        [guid]
        $SubscriptionId,

        # The location that will be used as a reference for version (not as a filter based on location, you will get the list of service tags with prefix details across all regions but limited to the cloud that your subscription belongs to).
        [Parameter(Mandatory = $true)]
        [string]
        $Location,

        # Access token
        [Parameter(Mandatory = $true)]
        [string]
        $AccessToken,

        # Service Tag name
        [Parameter(Mandatory = $true)]
        [string]
        $ServiceTag
    )
    
    $url = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Network/locations/$Location/serviceTags?api-version=2022-09-01"

    $headers = @{
        Authorization = "Bearer $AccessToken"
    }
    $params = @{
        Uri     = $url
        Method  = 'Get'
        Headers = $headers
    }
    $result = Invoke-WebRequest @params

    if ($result.StatusCode -eq 200) {
        $ipAddresses = (($result.Content | ConvertFrom-Json).Values | Where-Object {
            $_.Name -like 'AzureActiveDirectory'}).properties.addressPrefixes
        return $ipAddresses
    }
    else {
        Write-Output ("Failed retrieving the list of IP addresses representing the Service Tag ({0}). Exception: {1}" -f $ServiceTag, $result.StatusDescription)
    }
}


$accessToken = Get-AzureADToken -ApplicationId $ApplicationId -TenantId $TenantId -ClientSecret $ClientSecret

Get-AzureServiceTag -SubscriptionId $SubscriptionId -Location $Location -AccessToken $accessToken -ServiceTag $ServiceTag