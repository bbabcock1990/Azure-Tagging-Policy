<#
.SYNOPSIS
    Automated process of adding resource tags from Resource Group.
.DESCRIPTION
    This script is intended to automatically add Tags from a Resource
    Group down to the resources that live under the Resource Group.
    This runbook is triggered via a Azure Automation running on a trigger.
    
.NOTES
    Script is offered as-is with no warranty, expressed or implied.
    Test it before you trust it
    Author      : Brandon Babcock
    Website     : https://www.linkedin.com/in/brandonbabcock1990/
    Version     : 1.0.0.0 Initial Build
#>

# Variables

# Azure Tenant ID
$aadTenantId = Get-AutomationVariable -Name 'aadTenantId'

# Azure Subscription ID
$azureSubId = Get-AutomationVariable -Name 'azureSubId'


# Add tags to resources from parent Resource Group
function Add-ResourceGroupTagsToResources() 
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $resourceGroupName
    )
    # Get Resource Groups Under Subscription
    $resourceGroup = Get-AzResourceGroup $resourceGroupName


    # If The Resource Group Has Tags Then...
    if ($null -ne $resourceGroup.Tags) 
    {
        
        # Get All Resources Under Resource Group
        $resources = Get-AzResource -ResourceGroupName $resourceGroupName

        # Cycle Through Each Resource
        foreach ($r in $resources)
        {
            $tagChanges = $false
            Write-Output "Processing Resource: $($r.Name)"
            # Get Each Resource's Current Tags
            $resourcetags = (Get-AzResource -ResourceId $r.ResourceId).Tags
            
            # If The Resource Has Tag Then..
            if ($resourcetags)
            {
                # For Each Resource Group Tag...
                foreach ($resourceGroupTag in $resourceGroup.Tags.Keys)
                {
                    # If The Resource Tag Is Not In Resource Group Tag List...
                    if (-not($resourcetags.ContainsKey($resourceGroupTag)))
                    {
                        Write-Output "Adding Tag: $($resourceGroupTag.Name) - $resourceGroupTag"

                        # Add The Resource Group Tag to the Resource Tag List
                        $resourcetags.Add($resourceGroupTag, $resourceGroup.Tags[$resourceGroupTag])
                        $tagChanges = $True
                    }
                    else
                    {
                        # If The Resource Tag Is Already In The Resource Group Tag, Do Nothing
                        if ($resourcetags[$resourceGroupTag] -eq $resourceGroup.Tags[$resourceGroupTag])
                        {
                             Write-Output "$($resourceGroupTag) Tag Is Already Set On $($r.Name)"
                        }
                    }
                }
            }
            else
            {
                # All tags missing
                Write-Output "Adding All Tags: $($r.Name) - All tags from RG"
                $tagsToWrite = $resourceGroup.Tags
                $tagChanges = $True
            }

            if ($tagChanges)
            {
                
                $muteVerbose=Set-AzResource -Tag $tagsToWrite -ResourceId $r.ResourceId -Force
                Write-Output "$($r.Name) Tags Are Up To Date!"
                
            }
        }
    }
    else
    {
        Write-Warning "$resourceGroupName Has No Tags Set."
    }
}


# Log into Azure
try {
    $creds = Get-AutomationPSCredential -Name 'WVD-Scaling-SVC'
    Connect-AzAccount -ErrorAction Stop -ServicePrincipal -SubscriptionId $azureSubId -TenantId $aadTenantId -Credential $creds
    Write-Verbose Get-RdsContext | Out-String -Verbose
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Error ("Error logging into Azure: " + $ErrorMessage)
    Break
}


#Get All The Subscriptions
$subscriptions = Get-AzSubscription

# Cycle Through Each Subscription
ForEach ($sub in $subscriptions)
{
    $subscription = Select-AzSubscription -SubscriptionId $sub.SubscriptionId
    Write-Output "Processing $($sub.Name) ($($sub.SubscriptionId))"

    # Get All The Resource Groups Under Current Subscription
    $allResourceGroups = Get-AzResourceGroup

    # Cycle Through Each Resource Group And Check Tags
    ForEach ($resourceGroup in $allResourceGroups) 
    {
        Write-Output "Processing $($resourceGroup.ResourceGroupName) ($($sub.Name))"
        Add-ResourceGroupTagsToResources -resourceGroupName $resourceGroup.ResourceGroupName
    }
}