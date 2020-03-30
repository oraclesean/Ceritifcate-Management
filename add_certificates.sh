#!/bin/bash

# Generate and add the certificates (root and chain) needed for adding a new SSL site
# The procedure for adding certificates is based on the work of Ruben De Vries in his blog post:
# http://rubendevries.blogspot.com/2017/02/example-utlhttp-and-ssltls-on-12c.html

PROGRAM=$(basename $0)
VERSION=1.0
AUTHOR="Sean Scott"
CONTACT="sean.scott@viscosityna.com"

cleanup() {
  rm $request
  rm $issuers
  rm $root_cert
  rm $chain_cert
  rm $result
  exit $1
}

error() {
  printf "$1\n"
  printf "Exiting...\n"
  cleanup 1
}

get_cert_info() {
  # Get the request information
  openssl s_client -connect $ssl_site:$ssl_port -showcerts </dev/null &> $request
    if [ "$?" -ne 0 ]
  then error "There was a problem getting the SSL request information"
  fi
  O=$(grep "depth=2"  $request | sed -e 's/^.*\(O.=.*$\)/\1/'  | awk -F'[=,]' '{print $2}' | sed -e 's/^\s//' -e 's/\s$//')
  OU=$(grep "depth=2" $request | sed -e 's/^.*\(OU.=.*$\)/\1/' | awk -F'[=,]' '{print $2}' | sed -e 's/^\s//' -e 's/\s$//')
  CN=$(grep "depth=2" $request | sed -e 's/^.*\(CN.=.*$\)/\1/' | awk -F'[=,]' '{print $2}' | sed -e 's/^\s//' -e 's/\s$//')
    if [ -z "$O" ]
  then error "There was a problem retrieving the organization name (O) from the certificate request"
  elif [ -z "$OU" ]
  then error "There was a problem retrieving the organizational unit (OU) from the certificate request"
  elif [ -z "$CN" ]
  then error "There was a problem retrieving the common name (CN) from the certificate request"
  fi
}

extract_certificate() {
  __infile=$1
  __outfile=$2
  __cert_id=$3

  __cert_end=$(grep -n 'END CERTIFICATE' $__infile | head -$__cert_id | tail -1 | cut -d: -f1)
  head -$__cert_end $__infile | tail -$(($__cert_end - $(grep -n 'BEGIN CERTIFICATE' $__infile | head -$__cert_id | tail -1 | cut -d: -f1) + 1)) > $__outfile
    if [ "$(grep "BEGIN CERTIFICATE" $__outfile | wc -l)" -ne 1 ] && [ "$(grep "END CERTIFICATE" $__outfile | wc -l)" -ne 1 ]
  then error "The extracted certificate does not contain a BEGIN or END CERTIFICATE lines"
  elif [ "$(head -1 $__outfile | grep "BEGIN CERTIFICATE" | wc -l)" -ne 1 ] && [ "$(tail -1 $__outfile | grep "END CERTIFICATE" | wc -l)" -ne 1 ]
  then error "The extracted certificate does not begin or end with BEGIN or END CERTIFICATE lines"
  fi
}

display_wallet() {
  __verb=$1

  printf "\nWallet contents $__verb adding certificates:\n"
  $ORACLE_HOME/bin/orapki wallet display -wallet $wallet_dir
}

add_certificate() {
  __certificate_type=$1
  __certificate=$2

    if [ "$showonly" ]
  then printf "\nDisplaying the $__certificate_type certificate:\n"
       cat $__certificate
  elif [ "$verbose" ]
  then printf "\nAdding the $__certificate_type certificate:\n"
       cat $__certificate
  fi

    if [ ! "$showonly" ]
  then $ORACLE_HOME/bin/orapki wallet add -wallet $wallet_dir -pwd $wallet_pwd -trusted_cert -cert $__certificate >$result
         if [ "$?" -ne 0 ]
       then
              if [ "$(grep "PKI-04003" $result | wc -l)" -eq 1 ]
            then printf "\nThe $__certificate_type certificate is already present in the wallet\n"
            else error "There was an error adding the $__certificate_type certificate"
            fi
       else cat $result
            printf "\nCertificate added\n"
       fi
  fi
}

usage() {
  printf " $PROGRAM version $VERSION \n\n"
  printf " Generates certificates needed for Oracle SSL connections using UTL_HTTP and adds them to a wallet. \n\n"
  printf " Usage: $PROGRAM [-d|--database SID] [-w|--wallet <wallet directory>] [-p|--password <wallet password>] \n"
  printf "                 [-u|--url <https site>] (-P <SSL port> ) (-b|--bundle <cs bundle file>) \n"
  printf "                 (-v|--verbose) (-x) (-h|--help) \n\n"
  printf " Required: \n"
  printf "  -d [database name], --database [database name] \n"
  printf "                        Oracle database name. \n"
  printf "  -w [wallet directory], --wallet [wallet directory] \n"
  printf "                        Oracle wallet directory. \n"
  printf "  -p [wallet password], --password [wallet password] \n"
  printf "                        Password for the Oracle wallet. \n"
  printf "  -u [URL], --url [URL] SSL site to add. \n\n"
  printf " Optional: \n"
  printf "  -P [port number]      SSL port (default=443) \n"
  printf "  -b [CA file], --bundle [CA file] \n"
  printf "                        Local certificate bundle (default=/etc/pki/tls/certs/ca-bundle.crt) \n"
  printf "  -v, --verbose         Print certificates before adding. \n"
  printf "  -x                    No change mode; display certificates and wallet contents only. \n"
  printf "  -h, --help            Print help. \n\n"
  printf " Author:  $AUTHOR\n"
  printf " Contact: $CONTACT\n\n"
  exit $1
}

help_and_exit() {
  printf "ERROR: $1\n\n"
  usage 1
}

sid=
wallet_dir=
wallet_pwd=
ssl_site=
ssl_port=443
cert_bundle=/etc/pki/tls/certs/ca-bundle.crt
showonly=
verbose=

while [[ $# -gt 0 ]]
   do option="$1"
 case $option in
      -d|--database)
      sid="$2"; shift 2
      ;;
      -w|--wallet)
      wallet_dir="$2"; shift 2
      ;;
      -p|--password)
      wallet_pwd="$2"; shift 2
      ;;
      -u|--url)
      ssl_site=$(echo $2 | sed -e 's|^.*\?://||' | sed -e 's|/.*$||' | egrep "(.com)|(.net)|(.org)$"); shift 2
      ;;
      -P)
      ssl_port="$2"; shift 2
      ;;
      -x)
      showonly=1; shift
      ;;
      -v|--verbose)
      verbose=1; shift
      ;;
      -h|--help)
      usage 0
      ;;
      *)
      help_and_exit "Invalid option" 1
      ;;
 esac
 done

  if [ -z "$sid" ]
then help_and_exit "A database SID is required"
elif [ -z "$wallet_dir" ]
then help_and_exit "A wallet directory is required"
elif [ -z "$wallet_pwd" ]
then help_and_exit "A wallet password is required"
elif [ -z "$ssl_site" ]
then help_and_exit "A URL is required"
elif [ ! -d "$wallet_dir" ] || [ ! -r "$wallet_dir" ]
then help_and_exit "The directory $wallet_dir does not exist of is not readable"
elif [ ! -f "$cert_bundle" ] || [ ! -r "$cert_bundle" ]
then help_and_exit "The certificate bundle file $cert_bundle does not exist or is not readable"
elif ! [[ $ssl_port =~ ^[0-9]{1,5}$ ]]
then help_and_exit "SSL port must be a numeric value between 0 and 99999"
elif [ "$(ps -ef | grep pmon | egrep "${sid}$" | grep -v grep | wc -l)" -ne 1 ]
then help_and_exit "The database SID must be a running database"
fi

request=$(mktemp)
issuers=$(mktemp)
root_cert=$(mktemp)
chain_cert=$(mktemp)
result=$(mktemp)

. oraenv <<< $sid >/dev/null

get_cert_info
extract_certificate $request $chain_cert 1

openssl crl2pkcs7 -nocrl -certfile $cert_bundle | openssl pkcs7 -print_certs -text -noout | grep "Issuer:" > $issuers
  if [ "$?" -ne 0 ]
then error "\nThere was an error reading the certificate bundle file $cert_bundle"
fi

cert_num=$(grep -n "CN=$CN" $issuers | grep "OU=$OU" | grep "O=$O" | cut -d: -f1)

extract_certificate $cert_bundle $root_cert $cert_num

display_wallet "before"
add_certificate root $root_cert
add_certificate chain $chain_cert
  if [ ! "$showonly" ]
then display_wallet "after"
fi

cleanup 0
