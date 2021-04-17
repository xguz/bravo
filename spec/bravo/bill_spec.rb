# encoding: utf-8
require 'spec_helper'

describe 'Bill' do
  describe '#bill_type' do
    context 'with valid types' do
      Bravo::BILL_TYPE.each do |bill_type, _|
        it 'returns the bill type' do
          bill = Bravo::Bill.new(bill_type: bill_type, invoice_type: :invoice)

          expect(bill.bill_type).to eq bill_type
        end
      end
    end

    context 'with an invalid type' do
      it 'raises an error' do
        msg = 'El valor de iva_condition debe estar incluído en [:bill_a, :bill_b]'
        expect {
          Bravo::Bill.new(bill_type: :invalid, invoice_type: :invoice)
        }.to raise_error(Bravo::NullOrInvalidAttribute, msg)
      end
    end
  end

  describe '#invoice_type' do
    context 'with valid types' do
      Bravo::BILL_TYPE.each do |bill_type, invoice_types|
        invoice_types.each do |invoice_type, _|
          it 'returns the the invoice type' do
            bill = Bravo::Bill.new(bill_type: bill_type, invoice_type: invoice_type)

            expect(bill.invoice_type).to eq invoice_type
          end
        end
      end
    end

    context 'with an invalid type' do
      it 'raises an error' do
        msg = 'invoice_type debe estar incluido en             [:invoice, :debit, :credit, :receipt]'
        expect {
          Bravo::Bill.new(bill_type: :bill_a, invoice_type: :invalid)
        }.to raise_error(Bravo::NullOrInvalidAttribute, msg)
      end
    end
  end

  describe '#iva_sum and #net_amount' do
    it 'calculate the IVA and net' do
      invoice = Bravo::Bill::Invoice.new(total: 100.89,
                                         document_type: 'CUIT',
                                         iva_condition: :consumidor_final,
                                         iva_type: :iva_10)

      expect(invoice.iva_sum).to be_within(0.005).of(9.59)
      expect(invoice.net_amount).to be_within(0.005).of(91.3)
    end
  end

  describe '#setup_bill' do
    it 'uses today dates as default', vcr: { cassette_name: 'setup_bill_given_date' } do
      bill = Bravo::Bill.new(bill_type: :bill_a, invoice_type: :invoice)
      invoice = Bravo::Bill::Invoice.new(total: 100.0,
                                         document_type: 'CUIT',
                                         iva_condition: :responsable_inscripto,
                                         iva_type: :iva_10)
      invoice.document_number = '36025649'
      bill.set_new_invoice(invoice)

      bill.setup_bill

      detail = bill.body['FeCAEReq']['FeDetReq']['FECAEDetRequest'].first

      expect(detail['FchServDesde']).to eq "20210419"
      expect(detail['FchServHasta']).to eq "20210419"
      expect(detail['FchVtoPago']).to   eq "20210419"
    end

    context 'credit/debit notes' do
      it 'includes Comprebantes Asociados', vcr: { cassette_name: 'setup_bill_cbte_asoc' } do
        bill = Bravo::Bill.new(bill_type: :bill_a, invoice_type: :credit)
        invoice = Bravo::Bill::Invoice.new(total: 100.0,
                                           document_type: 'CUIT',
                                           iva_condition: :responsable_inscripto,
                                           iva_type: :iva_10)
        invoice.document_number = '36025649'
        invoice.cbte_asocs = [{
          type: '01', # 01 - Invoice
          sale_point: '0004',
          number: '00000035'
        }]

        bill.set_new_invoice(invoice)

        bill.setup_bill

        detail = bill.body['FeCAEReq']['FeDetReq']['FECAEDetRequest'].first
        detail = detail['CbtesAsoc'][0]['CbteAsoc']

        expect(detail['Tipo']).to eq "01"
        expect(detail['PtoVta']).to eq "0004"
        expect(detail['Nro']).to   eq "00000035"
      end
    end
  end

  describe "#authorize" do
    context "when success", vcr: { cassette_name: 'authorize_success' }do
      before do
        @bill = Bravo::Bill.new(bill_type: :bill_a, invoice_type: :invoice)
        document = Bravo::Bill::Invoice.new(total: 100.0,
                                       document_type: 'CUIT',
                                       iva_condition: :responsable_inscripto,
                                       iva_type: :iva_10)
        document.document_number = '30711543267'
        @bill.set_new_invoice(document)
        @bill.authorize
      end

      it "returns true" do
        expect(@bill.authorized?).to eq true
      end

      it "returns the next number" do
        expect(@bill.response[:detail_response][0][:cbte_desde]).to eq "37"
      end

      it "returns cae" do
        expect(@bill.response[:detail_response][0][:cae]).to eq "71167929598913"
      end
    end

    context "when fails", vcr: { cassette_name: 'authorize_fails' } do
      before do
        @bill = Bravo::Bill.new(bill_type: :bill_a, invoice_type: :credit)
        document = Bravo::Bill::Invoice.new(total: 100.0,
                                       document_type: 'CUIT',
                                       iva_condition: :responsable_inscripto,
                                       iva_type: :iva_10)
        document.document_number = '30711543267'
        @bill.set_new_invoice(document)
        @bill.authorize
      end

      it "returns false" do
        expect(@bill.authorized?).to eq false
      end

      it "returns the next number" do
        expect(@bill.response[:detail_response][0][:cbte_desde]).to eq "2"
      end

      it "doesn't return cae" do
        expect(@bill.response[:detail_response][0][:cae]).to eq nil
        expect(@bill.response[:detail_response][0][:cae_fch_vto]).to eq nil
      end

      it "populate with the errors" do
        msg = "Si el comprobante es Debito o Credito, enviar estructura CbteAsoc o PeriodoAsoc."
        expect(@bill.response[:detail_response][0][:observaciones][:obs][:msg]).to eq msg
      end
    end
  end
end
