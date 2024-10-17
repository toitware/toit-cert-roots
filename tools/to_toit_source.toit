// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import bitmap show blit
import crypto.crc
import encoding.base64
import host.file
import host.directory
import tls
import tr show Translator

LABEL       ::= "# Label: \""
EXPIRY      ::= "# Expiry: "
SUBJECT     ::= "# Subject: "
FINGERPRINT ::= "# SHA256 Fingerprint: "
ARANY_START ::= "NETLOCK_ARANY"
BEGIN       ::= "-----BEGIN"
END         ::= "-----END"

class Cert:
  mixed_case_name /string
  name/string  // Toit-ified const name.
  sha_fingerprint /string?  // SHA256 Fingerprint
  data /ByteArray  // DER-encoded raw data.
  comment /string?
  is_deprecated/bool
  expiry/string?
  subject/string?

  constructor .mixed_case_name .name .sha_fingerprint .data --.expiry=null --.subject=null --.comment=null --.is_deprecated=false:

  print_on_stdout -> none:
    print "$(name)_BYTES_ ::= #["
    i := 0
    while i < data.size:
      chunk_size := min 18 (data.size - i)
      while chunk_size < data.size - i and (byte_array_encode_ data[i..i + chunk_size + 1]).size <= 78:
        chunk_size++
      section := data[i..i + chunk_size]
      extra := 78 - (byte_array_encode_ section).size
      print
          byte_array_encode_ section --extra=(extra > 4 ? 0 : extra)
      i += chunk_size
    print "]\n"
    print ""
    print "/**"
    print "$(mixed_case_name)."
    print "This certificate can be added to an HTTP client or a TLS socket with"
    print "  the --root_certificates argument."
    print "It can also be installed on the Toit process, to be used by all TLS"
    print "  sockets that do not have explicit roots, using its install method."
    if comment: print comment
    if sha_fingerprint != null:
      print "SHA256 fingerprint: $sha_fingerprint"
    if expiry != null:
      print "Expiry: $expiry"
    if subject != null:
      print "Subject: $subject"
    hash := tls.add_global_root_certificate_ data

    print "*/"
    if is_deprecated:
      print "$name ::= $(name)_"
      print "$(name)_ ::= tls.RootCertificate --fingerprint=0x$(%x hash) $(name)_BYTES_"
    else:
      print "$name ::= tls.RootCertificate --fingerprint=0x$(%x hash) $(name)_BYTES_"
    print ""

byte_array_encode_ slice/ByteArray --extra/int=0 -> string:
  list := List slice.size: slice[it]
  return "    $((list.map: encode_byte_ it --extra=extra: extra -= it).join ","),"

encode_byte_ byte/int --extra/int=0 [report_extra]-> string:
  if ' ' <= byte <= '~' and byte != '\\' and byte != '\'': return "'$(%c byte)'"
  min_size := "$byte".size
  ["0x$(%02x byte)", "0x$(%x byte)", "$byte"].do: | alt |
    if alt.size - min_size <= extra:
      report_extra.call alt.size - min_size
      return alt
  unreachable

main args/List:
  in_cert_data := false
  name := null
  expiry := null
  subject := null
  fingerprint := null
  mixed_case_name := null
  all_certs := {:}  // Mapping from name in the input to Cert object.
  cert_code := []

  print "/// Root certificates, automatically extracted from Mozilla's NSS"
  print ""
  print "// This file was autogenerated from certdata.txt, which carried the"
  print "// following copyright message:"
  print ""
  print "// This Source Code Form is subject to the terms of the Mozilla Public"
  print "// License, v. 2.0. If a copy of the MPL was not distributed with this"
  print "// file, You can obtain one at http://mozilla.org/MPL/2.0/."
  print ""
  print "import encoding.base64"
  print "import net.x509 as net"
  print "import tls"
  print ""
  print "import .get_root"
  print "export get_root_from_exception"
  print ""

  tr := Translator "a-z .-" "A-Z_"
  squeeze := Translator --squeeze "_" "_"

  (file.read_content args[0]).to_string.trim.split "\n": | line |
    line = line.trim
    if line.starts_with FINGERPRINT:
      fingerprint = line[FINGERPRINT.size..]

    if line.starts_with LABEL:
      mixed_case_name = line[LABEL.size..line.size - 1]
      while all_certs.contains mixed_case_name:
        mixed_case_name += " new"
      name = tr.tr mixed_case_name
      if name.starts_with ARANY_START:
        name = "NETLOCK_ARANY"
      name = squeeze.tr name
    if line.starts_with EXPIRY:
      expiry = line[EXPIRY.size..EXPIRY.size + 10]
    if line.starts_with SUBJECT:
      subject = line[SUBJECT.size..]
    if line.starts_with BEGIN:
      in_cert_data = true
    else if line.starts_with END:
      data := base64.decode (cert_code.join "")
      all_certs[mixed_case_name] =
          Cert
              mixed_case_name
              name
              fingerprint
              data
              --expiry=expiry
              --subject=subject
      fingerprint = null
      in_cert_data = false
      expiry = null
      cert_code = []
    else if in_cert_data:
      cert_code.add line

  names := all_certs.keys.sort
  names.do: | mixed_case_name |
    cert/Cert := all_certs[mixed_case_name]
    cert.print_on_stdout

  print ""
  print "/**"
  print "A map from certificate name to \$tls.RootCertificate objects."
  print "The certificates can be used for the --root_certificates"
  print "  argument of TLS sockets."
  print "The certificates can also be installed as globally trusted"
  print "  roots using their install method."
  print "*/"
  print "MAP ::= {"
  names.do: | mixed_case_name |
    cert := all_certs[mixed_case_name]
    if not cert.name.contains "TUNTRUST":
      print "  \"$mixed_case_name\": $(cert.name),"
  print "  \"AAA Certificate Services\": COMODO_AAA_SERVICES_ROOT,"
  print "}"
  print ""
  print "/**"
  print "All the trusted roots in the collection.  If you are running"
  print "  on a non-embedded platform with plenty of memory you can just"
  print "  use them all."
  print "#Note"
  print "The TunTrust cert is only intended for .tn domains, but"
  print "  currently we do not support this restriction in our TLS code,"
  print "  therefore it is currently omitted here, and in \$MAP, but is"
  print "  available on an opt-in basis."
  print "#Examples"
  print "```"
  print "  socket := tls.Socket.client tcp"
  print "      --server_name=host"
  print "      --root_certificates=certificate_roots.ALL"
  print "```"
  print "*/"
  print "ALL ::= ["
  names.do: | mixed_case_name |
    cert := all_certs[mixed_case_name]
    if not cert.name.contains "TUNTRUST":
      if cert.is_deprecated:
        print "  $(cert.name)_,"
      else:
        print "  $cert.name,"
  print "]"
  print ""
  print "// Tries to parse a DER-encoded certificate in the most"
  print "// memory-efficient way.  On older VMs, that that fails."
  print "// In that case, it re-encodes the certificate in PEM"
  print "// format, and retries."
  print "parse_ der_encoded_cert/ByteArray -> net.Certificate:"
  print "  catch:"
  print "    return net.Certificate.parse der_encoded_cert"
  print "  lines := [\"-----BEGIN CERTIFICATE-----\"]"
  print "  List.chunk_up 0 der_encoded_cert.size 144: | from to |"
  print "    encoded := base64.encode der_encoded_cert[from..to]"
  print "    List.chunk_up 0 encoded.size 64: | f t |"
  print "      lines.add encoded[f..t]"
  print "  lines.add \"-----END CERTIFICATE-----\\n\""
  print "  return net.Certificate.parse (lines.join \"\\n\")"
  print ""
  print "/**"
  print "Installs all certificate roots on this process so that they are used"
  print "  for any TLS connections that do not have explicit root certificates."
  print "This adds about 180k to the program size."
  print "*/"
  print "install_all_trusted_roots -> none:"
  names.do: | mixed_case_name |
    cert/Cert := all_certs[mixed_case_name]
    hash := tls.add_global_root_certificate_ cert.data
    print "  $(cert.name).install"
  print ""
  print "/**"
  print "Common certificate roots."
  print "*/"
  print "COMMON_TRUSTED_ROOTS ::= ["
  print "  DIGICERT_GLOBAL_ROOT_G2,"
  print "  DIGICERT_GLOBAL_ROOT_CA,"
  print "  GLOBALSIGN_ROOT_CA,"
  print "  GLOBALSIGN_ROOT_CA_R3,"
  print "  COMODO_RSA_CERTIFICATION_AUTHORITY,"
  print "  BALTIMORE_CYBERTRUST_ROOT,"
  print "  USERTRUST_ECC_CERTIFICATION_AUTHORITY,"
  print "  USERTRUST_RSA_CERTIFICATION_AUTHORITY,"
  print "  DIGICERT_HIGH_ASSURANCE_EV_ROOT_CA,"
  print "  ISRG_ROOT_X1,"
  print "  STARFIELD_CLASS_2_CA,"
  print "  COMODO_AAA_SERVICES_ROOT,"
  print "]"
  print ""
  print "/**"
  print "Installs common certificate roots on this process so that they are used"
  print "  for any TLS connections that do not have explicit root certificates."
  print "This adds about 14k to the program size."
  print "*/"
  print "install_common_trusted_roots -> none:"
  print "  COMMON_TRUSTED_ROOTS.do: it.install"
