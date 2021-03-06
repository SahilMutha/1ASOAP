function Invoke-1ASOAPOperation
{
    param(
        [Parameter(Mandatory = $false,ParameterSetName = "Parameter")]
        [System.Object]$Proxy,
        [Parameter(Mandatory = $true,ValueFromPipeline = $true, ParameterSetName = "Pipeline")]
        [System.Object]$PipedProxy,
        [Parameter(Mandatory = $false, ParameterSetName = "Parameter")]
        [Parameter(Mandatory = $false, ParameterSetName = "Pipeline")]
        [string]$Operation,
        [Parameter(Mandatory = $false, ParameterSetName = "Parameter")]
        [Parameter(Mandatory = $false, ParameterSetName = "Pipeline")]
        [System.Object]$Parameter
    )

    begin
    {
        Write-Debug "PSCmdlet.ParameterSetName=$($PSCmdlet.ParameterSetName)"
        foreach ($psbp in $PSBoundParameters.GetEnumerator()) {Write-Debug "$($psbp.Key)=$($psbp.Value)"}
    }

    process
    {
        $Proxy=Get-SOAPProxy -Hashtable $PSBoundParameters

        $faultError = $null
        try
        {
            $transactionStatusCode = $Proxy|Get-1ASOAPSession -TransactionStatusCode
            Write-Debug "transactionStatusCode=$transactionStatusCode"
            switch ($transactionStatusCode)
            {
                'None'
                {
                    $Proxy | 
                        Start-1ASOAPSession -PassThru |
                        Set-1ASOAPSessionAMAHeader
                    
                    Write-Verbose "Starting new session"
                }
                'Start'
                { 
                    $Proxy | Set-1ASOAPSessionAMAHeader
                    Write-Verbose "Starting new session"
                }
                'InSeries'
                { 
                    $Proxy | Clear-1ASOAPSessionAMAHeader

                    $session = $Proxy|Get-1ASOAPSession
                    Write-Debug "session.SessionId=$($session.SessionId)"
                    Write-Debug "session.SecurityToken=$($session.SessSecurityTokenionId)"
                    Write-Verbose "Using session with SessionId=$($session.SessionId) and SecurityToken=$($session.SecurityToken)"
                }
                'End'
                { 
                    $session = $Proxy|Get-1ASOAPSession
                    $Proxy | 
                        Start-1ASOAPSession -PassThru |
                        Set-1ASOAPSessionAMAHeader
                    
                    Write-Warning "Found ended SessionId=$($session.SessionId) and SecurityToken=$($session.SecurityToken). Starting new session"
                }
            }
            $response = $Proxy.$Operation($Parameter)
        }
        catch
        {
            if($null -ne $_.Exception.InnerException)
            {
                $faultError = $_.Exception.InnerException
                switch ($faultError.GetType().Fullname)
                {
                    "System.Web.Services.Protocols.SoapHeaderException"
                    { 
                        Write-Debug "faultError.Code=$($faultError.Code)"
                        Write-Debug "faultError.Message=$($faultError.Message)"
                        Write-Debug "faultError.Actor=$($faultError.Actor)"
                        Write-Error $faultError.Message
                    }
                }
            }
            throw
        }
        finally
        {
            $session = $Proxy|Get-1ASOAPSession
            Write-Debug "Detected TransactionStatusCode=$($session.TransactionStatusCode) session with SessionId=$($session.SessionId) and SecurityToken=$($session.SecurityToken)"
            $response
        }
    }

    end
    {
        
    }
}