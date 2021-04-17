require 'bravo'
require 'pp'

# Set up Bravo defaults/config.
Bravo.pkey              = 'spec/fixtures/certs/pkey'
Bravo.cert              = 'spec/fixtures/certs/cert.crt'
Bravo.cuit              = '20333610907'
Bravo.sale_point        = '0004'
Bravo.default_concepto  = 'Servicios'
Bravo.default_moneda    = :peso
Bravo.own_iva_cond      = :responsable_inscripto
Bravo.openssl_bin       = '/usr/local/Cellar/openssl/1.0.2s/bin/openssl'
Bravo::AuthData.environment = :test
Bravo.logger.log = true

puts "Let's issue a Factura A for 1000 ARS to a Responsable Inscripto with 10.5% of IVA"

bill_a = Bravo::Bill.new(bill_type: :bill_a,
                         invoice_type: :invoice)

invoice = Bravo::Bill::Invoice.new(total: 1000.0,
                                   document_type: 'CUIT',
                                   iva_condition: :responsable_inscripto,
                                   iva_type: :iva_10)
invoice.document_number = '30711543267'
bill_a.set_new_invoice(invoice)

bill_a.authorize

puts "Authorization result = #{ bill_a.authorized? }"
puts "Authorization response."
pp bill_a.response

########################################################

puts "Let's issue a Recibo B for 100 ARS to a Consumidor Final"

bill_b = Bravo::Bill.new(bill_type: :bill_b,
                         invoice_type: :receipt)

invoice = Bravo::Bill::Invoice.new(total: 100.0,
                                   document_type: 'DNI',
                                   iva_condition: :consumidor_final,
                                   iva_type: :iva_0)
invoice.document_number = '36025649'
bill_b.set_new_invoice(invoice)

bill_b.authorize

puts "Authorization result = #{ bill_b.authorized? }"
puts "Authorization response."
pp bill_b.response

########################################################

puts "Let's issue a CreditNote A for 1 ARS to a Responsable Inscripto with 10.5% of IVA"

credit_bill_a = Bravo::Bill.new(bill_type: :bill_a, invoice_type: :credit)

credit = Bravo::Bill::Invoice.new(total: 1.0,
                                  document_type: 'CUIT',
                                  iva_condition: :responsable_inscripto,
                                  iva_type: :iva_10)

credit.document_number = '30711543267'

credit.cbte_asocs = [
  {
    type: '01', # 01 - Invoice
    sale_point: '0004',
    number: '00000052'
  },
  {
    type: '01', # 01 - Invoice
    sale_point: '0004',
    number: '00000053'
  }
]
credit_bill_a.set_new_invoice(credit)

credit_bill_a.authorize

puts "Authorization result = #{ credit_bill_a.authorized? }"
puts "Authorization response."
pp credit_bill_a.response
