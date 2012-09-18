package Business::BR::NFe::RPS;
use Moose;
use namespace::autoclean;

# TODO
# add writers
# add POD
# do everything

has ccm => (
    is => 'ro',
);

has serie => (
    is => 'ro',
);

has number => (
    is => 'ro',
);


# RPS   ­ Recibo Provisório de Serviços
# RPS-M ­ Recibo Provisório de Serviços proveniente de Nota Fiscal Conjugada (Mista)
# RPS-C ­ Cupom
has type => (
    is => 'ro',
    default => 'RPS',
);

has issue_date => (
    is => 'ro'
);

# N ­ Normal
# C ­ Cancelada
# E ­ Extraviada
has status => (
    is => 'ro',
    default => 'N',
);

# T - Tributação no município de São Paulo
# F - Tributação fora do município de São Paulo
# I ­ Isento
# J - ISS Suspenso por Decisão Judicial
has taxation => (
    is => 'ro'
    default => 'I'
);

has services_amount => (
    is => 'ro',
    isa => 'Num',
);

has deductions_amount => (
    is => 'ro',
    isa => 'Num',
);

has service_code => (
    is => 'ro',
);

# Alíquota dos Serviços
has services_tax_rate => (
    is => 'ro',
);

# ISS retido
has withheld_tax => (
    is => 'ro',
    isa => 'Bool'
);

has contractor_RPS => (
    is => 'ro',
);

has breakdown => (
    is => 'ro',
);

__PACKAGE__->meta->make_immutable;

1;
