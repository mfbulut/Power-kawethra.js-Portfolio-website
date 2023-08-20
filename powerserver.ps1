class Power {
    [String] $Port
    [String] $HTMLBlob
    [System.Net.HttpListener] $HttpListener
    [System.Collections.ArrayList] $Routes
    [String] $File
    Power() {
        $this.Routes = [System.Collections.ArrayList]::new()
        $this.HttpListener = [System.Net.HttpListener]::new()    
    }
    
    [Void] Run([String]$port) {
        $this.Port = $port
        $this.HttpListener.Prefixes.Add("http://localhost:$port/")
        $this.HttpListener.Start()
        
        write-host "HTTP Server Ready!" -f 'black' -b 'green'
        write-host "Now try going to $($this.HttpListener.Prefixes)" -f 'yellow'
        write-host "Then try going to $($this.HttpListener.Prefixes)other/path" -f 'yellow'
        
        while ($this.HttpListener.IsListening) {
            if ([Console]::KeyAvailable){
                $readkey = [Console]::ReadKey($true)
                if ($readkey.Modifiers -eq "Control" -and $readkey.Key -eq "C"){                
                    break
                }
            }

            $context = $this.HttpListener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            $matchedRoute = $this.Routes | Where-Object { $_.Method -eq $request.HttpMethod -and $_.Route -eq $request.RawUrl }

            if ($matchedRoute) {
                $action = $matchedRoute.Action
                $action.Invoke($context)
            } else {
                $response.ContentType = "text/html"
                $response.ContentEncoding = [System.Text.Encoding]::UTF8

                $htmlContent = "<h4>404 Page not found</h4>"

                $buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            $response.Close()
        }
    }

    [Void] GET([String]$route, [ScriptBlock]$action) {
        $this.Routes.Add(@{
            "Method" = "GET"
            "Route" = $route
            "Action" = $action
        })
    }

    [Void] POST([String]$route, [ScriptBlock]$action) {
         $this.Routes.Add(@{
            "Method" = "POST"
            "Route" = $route
            "Action" = $action
        })
    }

    [Void] PublicFile([String]$route, [String]$filePath) {
        $action = [ScriptBlock]::Create(@"
            param(`$context)
            
            `$response = `$context.Response
            `$response.ContentType = "application/json"
            `$response.ContentEncoding = [System.Text.Encoding]::UTF8

            `$externalParam = Get-Content -Path "$filePath" -Raw

            `$buffer = [System.Text.Encoding]::UTF8.GetBytes("`$externalParam")
            `$response.ContentLength64 = `$buffer.Length
            `$response.OutputStream.Write(`$buffer, 0, `$buffer.Length)
"@
        )

        $this.Routes.Add(@{
            "Method" = "GET"
            "Route" = $route
            "Action" = $action
        })
    }

    [Hashtable] PostForm($context){
        $FormContent = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

        $formData = @{}

        $formFields = $FormContent -split '&'
        foreach ($field in $formFields) {
            $keyValue = $field -split '='
            $key = [System.Uri]::UnescapeDataString($keyValue[0])
            $value = [System.Uri]::UnescapeDataString($keyValue[1])
            $formData[$key] = $value
        }

        return $formData
    }

    [Void] HTML($response, [String]$filePath, [Hashtable]$variables) {
        $htmlContent = Get-Content -Path $filePath -Raw
        foreach ($key in $variables.Keys) {
            $htmlContent = $htmlContent -replace "{{ .$key }}", $variables[$key]
        }
        
        $response.ContentType = "text/html"
        $response.ContentEncoding = [System.Text.Encoding]::UTF8

        $buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }

    [Void] JSON($response, $Api) {
        $response.ContentType = "application/json"
        $response.ContentEncoding = [System.Text.Encoding]::UTF8
        $jsonData =  $Api | ConvertTo-Json
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }

    [String] GetCookie([String]$cookieName, [System.Net.HttpListenerRequest]$request) {
        $cookieValue = $null
        $cookies = $request.Cookies
        
        foreach ($cookie in $cookies) {
            if ($cookie.Name -eq $cookieName) {
                $cookieValue = $cookie.Value
                break
            }
        }
        
        return $cookieValue
    }

    [Void] SetCookie([String]$cookieName, [String]$cookieValue, [String]$cookiePath, [DateTime]$cookieExpiration, [System.Net.HttpListenerResponse]$response) {
        $cookieExpirationFormatted = $cookieExpiration.ToUniversalTime().ToString("R")
        $response.Headers.Add("Set-Cookie", "$cookieName=$cookieValue; Expires=$cookieExpirationFormatted; Path=$cookiePath")
    }

    [String] Params($request,[String] $params) {
       $webParam = $request.QueryString[$params]
       return $webParam
    }

    [Void] Redirect([System.Net.HttpListenerResponse] $response, [String] $pageUrl) {
        Invoke-WebRequest -uri "$pageUrl" -Method get -maximumredirection 0;
    }
}

$power = [Power]::new()
$power.PublicFile("/kawethra.js","$pwd\kawethra.js")
$power.PublicFile("/components/home.kw","$pwd\components\home.kw")
$power.PublicFile("/components/projects.kw","$pwd\components\projects.kw")
$power.PublicFile("/components/contact.kw","$pwd\components\contact.kw")

$power.GET("/", {
    $context = $args[0]
    $response = $context.Response

    $variables = @{
        "title" = "Anasayfa"
        "redirect" = "#"
    }
    $power.HTML($response, "$pwd\index.html", $variables)
})

$power.Run("8080")
