# Análise Técnica do Código Terraform

1. Leitura do Arquivo:
Este arquivo Terraform tem como objetivo provisionar uma infraestrutura na AWS, utilizando os serviços de rede e computação. Ele cria uma VPC, uma sub-rede, um gateway de internet, um grupo de segurança, uma instância EC2 (Debian), e configurações de rota e chave SSH para acessar a instância.


2. Descrição Técnica:
Aqui está uma descrição detalhada do que cada recurso faz no arquivo:

### Provedor AWS

```bash
provider "aws" {
  region = "us-east-1"
}
```
`Provedor AWS:` Define o provedor que o Terraform vai usar, neste caso, a AWS, e a região onde os recursos serão provisionados (us-east-1).

### Variáveis
```bash
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}
```

`Variáveis`: Definem dois parâmetros de configuração:
`projeto`: Nome do projeto (valor padrão: "VExpenses").
`candidato`: Nome do candidato (valor padrão: "SeuNome").


#### Chave SSH
```bash
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}
```
`tls_private_key`: Gera uma chave privada RSA de 2048 bits, usada para acessar a instância EC2.
`aws_key_pair`: Cria um par de chaves na AWS, usando a chave pública gerada anteriormente. O nome da chave é formatado com o nome do projeto e do candidato.

#### VPC (Virtual Private Cloud)

```bash
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}
```
`aws_vpc`: Cria uma VPC com o bloco CIDR 10.0.0.0/16. A VPC terá suporte para DNS e hostnames ativados.

#### Sub-rede

```bash
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
```

`aws_subnet`: Cria uma sub-rede dentro da VPC, com o bloco CIDR 10.0.1.0/24, localizada na zona de disponibilidade us-east-1a.

#### Internet Gateway

```bash
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}
```
`aws_internet_gateway`: Cria um Internet Gateway para permitir que a VPC se conecte à internet.


#### Tabela de Rotas

```bash
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}
```

`aws_route_table`: Cria uma tabela de rotas para a VPC, permitindo tráfego para todos os endereços (0.0.0.0/0) através do Internet Gateway.


#### Associação da Tabela de Rotas

```bash
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}
```
`aws_route_table_association`: Associa a sub-rede à tabela de rotas criada anteriormente. 
> OBS: aws_route_table_association não tem suporte a tags 

#### Grupo de Segurança

```bash
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH de qualquer lugar e todo o tráfego de saída"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "Allow SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}
```

`aws_security_group`: Cria um grupo de segurança permitindo:
`Entrada (ingress)`: Tráfego SSH (porta 22) de qualquer endereço IPv4 e IPv6 (0.0.0.0/0 e ::/0).
`Saída (egress)`: Todo o tráfego de saída é permitido para qualquer destino.


#### AMI (Amazon Machine Image)
```bash
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}
```

`aws_ami`: Seleciona a AMI mais recente do Debian 12(sistema operancional linux) com virtualização HVM.

#### Instância EC2

```bash
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
```

`aws_instance:` Cria uma instância EC2 utilizando a AMI do Debian 12. É uma instância t2.micro que está associada à sub-rede e à chave SSH criada. Além disso, é associado um volume root de 20 GB (gp2), e a instância recebe um IP público.


#### Outputs

```bash
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
```

`private_key`: Exibe a chave privada gerada para acesso à instância.
`ec2_public_ip`: Exibe o IP público da instância EC2.


3. Observações:
Ocorre um erro porque o recurso `aws_route_table_association` não suporta a propriedade tags(linha 73). No Terraform, nem todos os recursos têm suporte para tags, e esse é o caso das associações de tabelas de roteamento (aws_route_table_association).

Solução:
Você deve remover o bloco tags da configuração desse recurso. Aqui está a correção do código:
```bash
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}
```
Explicação:
O recurso aws_route_table_association serve apenas para associar uma sub-rede a uma tabela de roteamento, e não permite o uso de tags. Se você quiser adicionar tags, pode aplicá-las diretamente à tabela de roteamento (aws_route_table) ou a outros recursos que suportem tags.





# Modificações e melhorias para o codigo Terraform

- **Segurança:** A regra de segurança para SSH permite acesso de qualquer lugar (0.0.0.0/0), o que pode representar um risco de segurança. Idealmente, o tráfego SSH deveria ser limitado a um IP ou range de IPs confiáveis ou.


- **Tamanho da Instância:** A instância EC2 criada é do tipo t2.micro, que é de baixo custo e adequada para pequenos testes ou desenvolvimento, mas pode não ser suficiente para ambientes de produção.

- **Chave Privada:** A chave privada é sensível e, por segurança, é exibida como uma saída sensível (sensitive = true), o que é uma boa prática para evitar exposição inadvertida da chave.