module Bravo
  # This class handles authorization data
  #
  class AuthData
    class << self
      attr_accessor :environment, :todays_data_file_name

      # Fetches WSAA Authorization Data to build the datafile for the day.
      # It requires the private key file and the certificate to exist and
      # to be configured as Bravo.pkey and Bravo.cert
      #
      def create
        raise "Archivo de llave privada no encontrado en #{ Bravo.pkey }" unless File.exist?(Bravo.pkey)
        raise "Archivo certificado no encontrado en #{ Bravo.cert }" unless File.exist?(Bravo.cert)

        Bravo::Wsaa.login(current_data_file) unless authorized_data?

        Bravo.const_set(:TOKEN, credentials[:token])
        Bravo.const_set(:SIGN, credentials[:sign])
      end

      # Returns the authorization hash, containing the Token, Signature and Cuit
      # @return [Hash]
      #
      def auth_hash
        create unless Bravo.constants.include?(:TOKEN) && Bravo.constants.include?(:SIGN)
        { 'Token' => Bravo::TOKEN, 'Sign' => Bravo::SIGN, 'Cuit' => Bravo.cuit }
      end

      # Returns the right wsaa url for the specific environment
      # @return [String]
      #
      def wsaa_url
        check_environment!
        Bravo::URLS[environment][:wsaa]
      end

      # Returns the right wsfe url for the specific environment
      # @return [String]
      #
      def wsfe_url
        check_environment!
        Bravo::URLS[environment][:wsfe]
      end

      # Creates the data file name for a cuit number and the current day
      # @return [String]
      #
      def current_data_file
        "/tmp/bravo_#{ Bravo.cuit }.yml"
      end

      # Checks the auth file exists and contains valid current data
      # @return [Boolean]
      #
      def currently_authorized?
        File.exist?(current_data_file) && authorized_data?
      end

      # Checks credentials are valid
      # @return [Boolean]
      #
      def authorized_data?
        DateTime.now < DateTime.parse(credentials[:expires_on])
      end

      # Reads current data file
      # @return [Hash]
      #
      def credentials
        YAML.load_file(current_data_file)
      end

      # Validates Bravo.environment is set and valid
      # @return [Boolean]
      #
      def check_environment!
        raise 'Environment not set.' unless Bravo::URLS.keys.include? environment
      end
    end
  end
end
