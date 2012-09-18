package Business::BR::NFe::SP::SaoPaulo;
use Crypt::OpenSSL::PKCS12;
use Crypt::OpenSSL::X509;
use Crypt::OpenSSL::RSA;
use MIME::Base64 qw/encode_base64/;
use Digest::SHA1 qw/sha1_base64/;
use Moose;
use namespace::autoclean;
use Carp;

has cnpj => (
    is => 'ro',
);

has ccm => (
    is => 'ro',
);

has cert_passphrase => (
    is => 'ro',
);

# TODO:
# come up with better defaults
has pkcs12 => (
    is => 'ro',
    #default => '/path/to/nfe/certificates/nfe.pfx',
);

has cert_dir => (
    is => 'ro',
    #default => '/path/to/nfe/certificates',
);

has private_key => (
    is => 'ro',
    lazy => 1,
    default => sub { shift->cert_dir . '/privatekey.pem' },
);

has public_key => (
    is => 'ro',
    default => sub { shift->cert_dir . '/publickey.pem' },
);

has key => (
    is => 'ro',
    default => sub { shift->cert_dir . '/key.pem' },
);

has X509Certificate => (
    is => 'ro',
);

has connection => (
    is => 'ro',
);

has url_xsi => (
    is => 'ro',
    default => 'http://www.w3.org/2001/XMLSchema-instance',
);

has url_xsd => (
    is => 'ro',
    default => 'http://www.w3.org/2001/XMLSchema',
);

has url_nfe => (
    is => 'ro',
    default => 'http://www.prefeitura.sp.gov.br/nfe',
);

has url_dsig => (
    is => 'ro',
    default => 'http://www.w3.org/2000/09/xmldsig#'
);

has url_canon_meth => (
    is => 'ro',
    default => 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315',
);

has url_sig_meth => (
    is => 'ro',
    default => 'http://www.w3.org/2000/09/xmldsig#rsa-sha1',
);

has url_transf_meth_1 => (
    is => 'ro',
    default => 'http://www.w3.org/2000/09/xmldsig#enveloped-signature',
);

has url_transf_meth_2 => (
    is => 'ro',
    default => 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315',
);

has url_digest_meth => (
    is => 'ro',
    default => 'http://www.w3.org/2000/09/xmldsig#sha1',
);

sub create_keys {
    my $self = shift;
    my $pkcs12 = Crypt::OpenSSL::PKCS12->new_from_file( $self->pkcs12 );
    my $cert = $pkcs12->certificate($self->cert_passphrase);

    if ( $self->validate_certificate($cert) ) {
        # TODO
        # do I really need to create the files on disk?
        # Renato cron: nao
        $self->_create_private_key( $pkcs12->private_key );
        $self->_create_public_key( $cert );
        $self->_create_key( $cert . $pkcs12->private_key );
    }
}

sub validate_certificate {
    my ($self, $cert) = @_;

    my $data = Crypt::OpenSSL::X509->new_from_string($cert);

    if (!$cert->checkend(5)) {
        croak 'Certificate is expired!';
    }

    return 1;
}

sub BUILD {
    my $self = shift;

    $self->create_keys;
}

sub _el {
    my ($name, $text) = @_;
    my $el = XML::LibXML::Element->new( $name );
    $el->appendText( $text ) if $text;
    return $el;
}

sub get_signed_rps {
    my ($self, $rps) = @_;

    my $content = sprintf( '%08s', $rps->taxPayerRegisterProvider ) .
                  sprintf('%-5s',$rps->serie ) .
                  sprintf( '%012s', $rps->number ) .
                  $rps->issue_date->strftime('%Y%m%d') .
                  $rps->taxation .
                  $rps->status .
                  ( $rps->withheld_tax ? 'S' : 'N' ) .
                  sprintf( '%015s', int(100 * $rps->services_amount) ).
                  sprintf( '%015s', int(100 * $rps->deductions_amount) ) .
                  sprintf( '%05s', $rps->service_code ) .
                  ( $rps->contractor->type == 'F' ? '1' : '2' ) .
                  sprintf( '%014s', $rps->contractor->federalTaxNumber );

    return $self->_sign_content($content);
}

sub _sign_content {
    my ($self, $content) = @_;

    my $rsa_priv = Crypt::OpenSSL::RSA->new_private_key($self->private_key);
    $rsa_priv->use_sha1_hash(); # it's the default, but let's be safe

    return encode_base64( $rsa_priv->sign($content) );
}

sub get_xml_node_for_rps {
    my ( $self, $rps ) = @_;

    my $node = XML::LibXML::Element->new( 'RPS' );

    $node->appendChild( _el( 'Assinatura' => $self->get_signed_rps( $rps ) ) );

    my $key = XML::LibXML::Element->new( 'ChaveRPS' );

    $key->appendChild( _el( 'InscricaoPrestador' => $rps->taxPayerRegisterProvider ) );

    $key->appendChild( _el( 'SerieRPS' => $rps->serie ) );

    $key->appendChild( _el( 'NumeroRPS' => $rps->number ) );

    $node->appendChild( $key );

    $node->appendChild( _el( 'TipoRPS' => $rps->type ) );

    $node->appendChild( _el( 'DataEmissao' => $rps->issue_date->strftime('%Y-%m-%d') ) );

    $node->appendChild( _el( 'StatusRPS' => $rps->status ) );

    $node->appendChild( _el( 'TributacaoRPS' => $rps->taxation ) );

    $node->appendChild( _el( 'ValorServicos', $rps->services_amount ) );
    $node->appendChild( _el( 'ValorDeducoes', $rps->deductions_amount ) );

    $node->appendChild( _el( 'CodigoServico', $rps->service_code ) );
    $node->appendChild( _el( 'AliquotaServicos', $rps->services_tax_rate ) );

    $node->appendChild( _el( 'ISSRetido', $rps->withheld_tax ? 'true' : 'false' ) );

    my $cnpj = _el( 'CPFCNPJTomador' );
    $cnpj->appendChild( _el( 'CNPJ', $rps->contractor->cpf_cnpj ) );
    $node->appendChild( $cnpj );

    $node->appendChild( _el( 'RazaoSocialTomador', $rps->contractor->name ) );
    $node->appendChild( _el( 'EmailTomador', $rps->contractor->email ) );

    $node->appendChild( _el( 'Discriminacao', $rps->breakdown ) );

    return $node;
}

sub set_xml_signature {
    my ($self, $root) = @_;

    my $digest = sha1_base64( $root->toStringC14N() );

    my $signature = _el( 'Signature' );
    $signature->setNamespace($self->url_dsig);

    my $signed_info = _el( 'SignedInfo' );

    my $canon = _el( 'CanonicalizationMethod' );
    $canon->setAttribute( 'Algorithm', $self->url_canon_meth );

    my $sig_method = _el( 'SignatureMethod' );
    $sig_method->setAttribute( 'Algorithm', $self->url_sig_meth );

    my $reference = _el( 'Reference' );
    $reference->setAttribute( 'URI', '' );

    my $transforms = _el( 'Transforms' );

    my $transform1 = _el( 'Transform' );
    $transform1->setAttribute( 'Algorithm', $self->url_transf_meth_1 );

    my $transform2 = _el( 'Transform' );
    $transform2->setAttribute( 'Algorithm', $self->url_transf_meth_2 );

    my $digest_method = _el( 'DigestMethod' );
    $digest_method->setAttribute( 'Algorithm', $self->url_digest_meth );

    my $digest_value_node = _el( 'DigestValue', $digest );


    $transforms->appendChild( $transform1 );
    $transforms->appendChild( $transform2 );

    $reference->appendChild( $transforms );
    $reference->appendChild( $digest_method );
    $reference->appendChild( $digest_value_node );

    $signed_info->appendChild( $canon );
    $signed_info->appendChild( $sig_method );
    $signed_info->appendChild( $reference );

    $signature->appendChild( $signed_info );

    $signature->appendChild( _el( 'SignatureValue', $self->_sign_content($signed_info->toStringC14N) ) );

    my $keyInfo  = _el('KeyInfo');
    my $x509Data = _el( 'X509Data' );

    $x509Data->appendChild( _el( 'X509Certificate', $self->X509Certificate ) );
    $keyInfo->appendChild( $x509Data );
    $signature->appendChild( $keyInfo );

    $root->appendChild( $signature );
}

sub create_xml_doc {
    my ($self, $operation) = @_;

    my $doc = XML::LibXML->createDocument( "1.0", "UTF-8" );

    # FIXME: perhaps I should be using some namespace method
    my $root = $doc->createElement("Pedido$operation");
    $root->setAttributeNS('xmlns', 'xsd', $self->url_xsd);
    $root->setAttributeNS('', 'xmlns', $self->url_nfe);
    $root->setAttributeNS('xmlns', 'xsi', $self->url_xsi);

    my $header = $doc->createElement( 'Cabecalho' );
    $header->setAttribute( 'Versao', 1 );

    my $cpf_cnpj = $doc->createElement( 'CPFCNPJRemetente' );
    my $cnpj = $doc->createElement( 'CNPJ' );
    $cnpj->appendText( $self->cnpj );
    $cpf_cnpj->appendChild( $cnpj );

    $header->appendChild( $cpf_cnpj );
    $root->appendChild( $header );

    $doc->setDocumentElement($root);

    return $doc;
}

sub send_rps {
    my ( $self, $rps ) = @_;

    my $operation = 'EnvioRPS';

    my $xml_doc = $self->create_xml_doc( $operation );

    my $node = $self->get_xml_node_for_rps( $rps );

    $xml_doc->documentElement->appendChild( $node );

    return $self->_send( $operation, $xml_doc );
}

sub _send {
    my ( $self, $operation, $xml ) = @_;
    $self->connect();

    $self->set_xml_signature($xml->documentElement);

    # ...
}

__PACKAGE__->meta->make_immutable;

1;
