require 'bravo'
require 'pp'

# Set up Bravo defaults/config.
Bravo.pkey              = 'spec/fixtures/certs/pkey'
Bravo.cert              = 'spec/fixtures/certs/cert'
Bravo.cuit              = '20085617517'
Bravo.sale_point        = '0004'
Bravo.default_concepto  = 'Servicios'
Bravo.default_moneda    = :peso
Bravo.own_iva_cond      = :responsable_inscripto
Bravo.openssl_bin       = '/usr/bin/openssl'
Bravo::AuthData.environment = :test

# Let's issue a Factura for 1200 ARS to a Responsable Inscripto
bill_a = Bravo::Bill.new(bill_type: :bill_a,
                         invoice_type: :invoice)

invoice = Bravo::Bill::Invoice.new(net: 1200,
                                   document_type: 'CUIT',
                                   iva_condition: :responsable_inscripto)
invoice.document_number = '30710151543'
bill_a.set_new_invoice(invoice)

bill_a.authorize

puts "Let's issue a Factura for 1200 ARS to a Responsable Inscripto"
puts "Authorization result = #{ bill_a.authorized? }"
puts "Authorization response."
pp bill_a.response

# Let's issue a Factura for 100 ARS to a Consumidor Final
bill_b = Bravo::Bill.new(bill_type: :bill_b,
                         invoice_type: :invoice)

invoice = Bravo::Bill::Invoice.new(net: 100,
                                   document_type: 'DNI',
                                   iva_condition: :consumidor_final)
invoice.document_number = '36025649'
bill_b.set_new_invoice(invoice)

bill_b.authorize

puts "Let's issue a Factura for 100 ARS to a Consumidor Final"
puts "Authorization result = #{ bill_b.authorized? }"
puts "Authorization response."
pp bill_b.response
