# Ceritifcate-Management
Add SSL/TLS certificates to Oracle Wallets
## About
Generate and add the root and chain certificates to an Oracle Wallet for accessing SSL sites via UTL_HTTP, etc.
Based on Ruben de Vries's blog post: http://rubendevries.blogspot.com/2017/02/example-utlhttp-and-ssltls-on-12c.html
## Use
```
Generates certificates needed for Oracle SSL connections using UTL_HTTP and adds them to a wallet.
 Usage: $PROGRAM [-d|--database SID] [-w|--wallet <wallet directory>] [-p|--password <wallet password>]
                 [-u|--url <https site>] (-P <SSL port> ) (-b|--bundle <cs bundle file>)
                 (-v|--verbose) (-x) (-h|--help)

 Required:
  -d [database name], --database [database name]
                        Oracle database name.
  -w [wallet directory], --wallet [wallet directory]
                        Oracle wallet directory.
  -p [wallet password], --password [wallet password]
                        Password for the Oracle wallet.
  -u [URL], --url [URL] SSL site to add.

 Optional:
  -P [port number]      SSL port (default=443)
  -b [CA file], --bundle [CA file]
                        Local certificate bundle (default=/etc/pki/tls/certs/ca-bundle.crt)
  -v, --verbose         Print certificates before adding.
  -x                    No change mode; display certificates and wallet contents only.
  -h, --help            Print help.
```
