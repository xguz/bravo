# encoding: utf-8
module Bravo
  # The main class in Bravo. Handles WSFE method interactions.
  # Subsequent implementations will be added here (maybe).
  #
  class Bill
    # Returns the Savon::Client instance in charge of the interactions with WSFE API.
    # (built on init)
    #
    attr_reader :client

    attr_accessor :iva_condition, :due_date, :date_from, :date_to, :body, :response, :invoice_type, :batch

    def initialize(attrs = {})
      opts = { wsdl: Bravo::AuthData.wsfe_url, ssl_version: :TLSv1 }.merge! Bravo.logger_options
      @client       ||= Savon.client(opts)
      @body           = { 'Auth' => Bravo::AuthData.auth_hash }
      @iva_condition  = validate_iva_condition(attrs[:iva_condition])
      @invoice_type   = validate_invoice_type(attrs[:invoice_type])
      @batch          = attrs[:batch] || []
    end

    def inspect
      %{#<Bravo::Bill iva_condition: "#{ iva_condition }", concept: "#{ concept }", \
currency: "#{ currency }", due_date: "#{ due_date }", date_from: #{ date_from.inspect }, \
date_to: #{ date_to.inspect }, invoice_type: #{ invoice_type }>}
    end

    def to_hash
      { iva_condition: iva_condition, invoice_type: invoice_type,
        due_date: due_date, date_from: date_from, date_to: date_to, body: body }
    end

    def to_yaml
      to_hash.to_yaml
    end

    # Searches the corresponding invoice type according to the combination of
    # the seller's IVA condition and the buyer's IVA condition
    # @return [String] the document type string
    #
    def bill_type
      Bravo::BILL_TYPE[Bravo.own_iva_cond][iva_condition][invoice_type]
    end

    def set_new_invoice(invoice)
      return false unless invoice.instance_of?(Bravo::Bill::Invoice)
      @batch << invoice
      invoice
    end

    # Files the authorization request to AFIP
    # @return [Boolean] wether the request succeeded or not
    #
    def authorize
      setup_bill
      response = client.call(:fecae_solicitar) do |soap|
        # soap.namespaces['xmlns'] = 'http://ar.gov.afip.dif.FEV1/'
        soap.message body
      end

      setup_response(response.to_hash)
      self.authorized?
    end

    # Sets up the request body for the authorisation
    # @return [Hash] returns the request body as a hash
    #
    def setup_bill
      fecaereq = setup_request_structure
      det_request = fecaereq['FeCAEReq']['FeDetReq']['FECAEDetRequest']
      last_cbte = Bravo::Reference.next_bill_number(bill_type)
      @batch.each_with_index do |invoice, index|
        cbte = last_cbte + index
        det_request << setup_invoice_structure(invoice, cbte)
      end
      body.merge!(fecaereq)
    end

    # Returns the result of the authorization operation
    # @return [Boolean] the response result
    #
    def authorized?
      !response.nil? && response.header_result == 'A' && invoices_result
    end

    private

    # Sets the header hash for the request
    # @return [Hash]
    #
    def header(bill_type)
      # toodo sacado de la factura
      { 'CantReg' => "#{@batch.size}", 'CbteTipo' => bill_type, 'PtoVta' => Bravo.sale_point }
    end

    def invoices_result
      response.detail_response.map{|invoice| invoice[:resultado] == 'A'}.all?
    end

    # Response parser. Only works for the authorize method
    # @return [Struct] a struct with key-value pairs with the response values
    #
    # rubocop:disable Metrics/MethodLength
    def setup_response(response)
      # TODO: turn this into an all-purpose Response class
      result          = response[:fecae_solicitar_response][:fecae_solicitar_result]

      response_header = result[:fe_cab_resp]
      response_detail = result[:fe_det_resp][:fecae_det_response]

      request_header  = body['FeCAEReq']['FeCabReq']
      request_detail  = body['FeCAEReq']['FeDetReq']['FECAEDetRequest']

      # request_detail.merge!(request_detail.delete(:iva)['AlicIva'])

      response_hash = { header_result:   response_header[:resultado],
                        authorized_on:   response_header[:fch_proceso],
                        header_response: response_header,
                        detail_response: response_detail
                      }

      keys, values = response_hash.to_a.transpose

      self.response = Struct.new(*keys).new(*values)
    end
    # rubocop:enable Metrics/MethodLength

    def validate_invoice_type(type)
      if Bravo::BILL_TYPE_A.keys.include? type
        type
      else
        raise(NullOrInvalidAttribute.new, "invoice_type debe estar incluido en \
            #{ Bravo::BILL_TYPE_A.keys }")
      end
    end

    def setup_request_structure
      { 'FeCAEReq' =>
        { 'FeCabReq' => header(bill_type),
          'FeDetReq' => {
            'FECAEDetRequest' => []
          } } }
    end

    def validate_iva_condition(iva_cond)
      valid_conditions = Bravo::BILL_TYPE[Bravo.own_iva_cond].keys
      if valid_conditions.include? iva_cond
        iva_cond
      else
        raise(NullOrInvalidAttribute.new,
          "El valor de iva_condition debe estar incluído en #{ valid_conditions }")
      end
    end

    def setup_invoice_structure(invoice, cbte)
      detail = {}
      detail['DocNro']    = invoice.document_number
      detail['ImpNeto']   = invoice.net.to_f
      detail['ImpIVA']    = invoice.iva_sum
      detail['ImpTotal']  = invoice.total
      detail['CbteDesde'] = detail['CbteHasta'] = cbte
      detail['Concepto']  = Bravo::CONCEPTOS[invoice.concept],
      detail['DocTipo']   = Bravo::DOCUMENTOS[invoice.document_type],
      detail['MonId']     = Bravo::MONEDAS[invoice.currency][:codigo],
      detail['Iva'] = {
        'AlicIva' => {
          'Id' => invoice.applicable_iva_code,
          'BaseImp' => invoice.net.round(2),
          'Importe' => invoice.iva_sum
        }
      }
      detail['CbteFch']     = today
      detail['ImpTotConc']  = 0.00
      detail['MonCotiz']    = 1
      detail['ImpOpEx']     = 0.00
      detail['ImpTrib']     = 0.00
      unless invoice.concept == 0
        detail.merge!('FchServDesde'  => date_from  || today,
                      'FchServHasta'  => date_to    || today,
                      'FchVtoPago'    => due_date   || today)
      end
    end

    def today
      Time.new.strftime('%Y%m%d')
    end

    class Invoice
      attr_accessor :net, :document_type, :document_number, :due_date, :aliciva_id, :date_from, :date_to,
        :iva_condition, :concept, :currency

      def initialize(attrs = {})
        @iva_condition  = validate_iva_condition(attrs[:iva_condition])
        @net            = attrs[:net]           || 0
        @document_type  = attrs[:document_type] || Bravo.default_documento
        @currency       = attrs[:currency]      || Bravo.default_moneda
        @concept        = attrs[:concept]       || Bravo.default_concepto
      end

      # Calculates the total field for the invoice by adding
      # net and iva_sum.
      # @return [Float] the sum of both fields, or 0 if the net is 0.
      #
      def total
        @total = net.zero? ? 0 : net + iva_sum
      end

      # Calculates the corresponding iva sum.
      # This is performed by multiplying the net by the tax value
      # @return [Float] the iva sum
      #
      # TODO: fix this
      #
      def iva_sum
        @iva_sum = net * applicable_iva_multiplier
        @iva_sum.round(2)
      end

      def validate_iva_condition(iva_cond)
        valid_conditions = Bravo::BILL_TYPE[Bravo.own_iva_cond].keys
        if valid_conditions.include? iva_cond
          iva_cond
        else
          raise(NullOrInvalidAttribute.new,
            "El valor de iva_condition debe estar incluído en #{ valid_conditions }")
        end
      end

      def applicable_iva
        index = Bravo::APPLICABLE_IVA[Bravo.own_iva_cond][iva_condition]
        Bravo::ALIC_IVA[index]
      end

      def applicable_iva_code
        applicable_iva[0]
      end

      def applicable_iva_multiplier
        applicable_iva[1]
      end
    end
  end
end
