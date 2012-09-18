package Business::BR::NFe::RPS::Contractor;
use Moose;
use namespace::autoclean;

# TODO
# add writers
# add POD
# do everything

has cpf_cnpj => (
    is => 'ro',
);

has ccm => (
    is => 'ro',
);

# C = Corporate (CNPJ), F = Personal (CPF)
has type => (
    is => 'ro',
    default => 'C',
);

has name => (
    is => 'ro',
);

has addressType => (
    is => 'ro',
);
has address => (
    is => 'ro',
);
has addressNumber => (
    is => 'ro',
);
has complement => (
    is => 'ro',
);
has district => (
    is => 'ro',
);
has city => (
    is => 'ro',
);
has state => (
    is => 'ro',
);
has zip_code => (
    is => 'ro',
);

has email => (
    is => 'ro',
);
has email2 => (
    is => 'ro',
);

__PACKAGE__->meta->make_immutable;

1;
