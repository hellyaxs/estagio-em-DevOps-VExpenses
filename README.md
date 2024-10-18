# Análise Técnica do Código Terraform

1. Leitura do Arquivo:
Este arquivo Terraform tem como objetivo provisionar uma infraestrutura na AWS, utilizando os serviços de rede e computação. Ele cria uma VPC, uma sub-rede, um gateway de internet, um grupo de segurança, uma instância EC2 (Debian), e configurações de rota e chave SSH para acessar a instância.


2. Descrição Técnica:
Aqui está uma descrição detalhada do que cada recurso faz no arquivo:

#### Provedor AWS

```bash
provider "aws" {
  region = "us-east-1"
}
```
`Provedor AWS:` Define o provedor que o Terraform vai usar, neste caso, a AWS, e a região onde os recursos serão provisionados (us-east-1).

#### Variáveis
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

`aws_instance:` Cria uma instância EC2 utilizando a AMI do Debian 12. É uma instância t2.micro que está associada à sub-rede e à chave SSH criada. Além disso, é associado um volume root de 20 GB (gp2), e a instância recebe um IP público, e ao instanciar a maquina ele atualiza todas a bibliotecas de dependencias.


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

As principais melhorias implementadas incluem:

1. **Estrutura Modular**: O código foi dividido em múltiplos arquivos para melhor organização e manutenibilidade. As responsabilidades foram separadas em arquivos como `variables.tf`, `network.tf`, `security.tf`, `instances.tf` e `outputs.tf`.

2. **Variáveis para Número de Instâncias**: A configuração permite a definição do número de instâncias EC2 a serem criadas, tornando o código mais flexível e reutilizável.

```bash
terraform apply -var="instance_count=3"
```

3. **Regras de Segurança Aprimoradas**: As regras de saída foram limitadas para permitir apenas tráfego HTTP, HTTPS e DNS, aumentando a segurança da infraestrutura. O uso de variáveis para as portas de saída permite que essas regras sejam definidas de forma dinâmica, facilitando alterações futuras.

4. **Proteção de SSH**: O acesso SSH foi restringido para permitir conexões apenas a partir de redes VPN específicas, reduzindo o risco de acesso não autorizado e tambem foi desabilitado o acesso ssh via root e password.

5. **Instalação Automatizada do Nginx**: A configuração da instância EC2 inclui um script de inicialização que instala e inicia o servidor Nginx automaticamente.


#### Descrição Técnica das Melhorias
Modularização: O código foi dividido em módulos para melhor organização e reutilização. Cada módulo tem uma responsabilidade clara, facilitando a manutenção e a compreensão do projeto.
Variáveis Dinâmicas: A adição de variáveis permite que o número de instâncias e as portas de saída sejam facilmente ajustados sem a necessidade de alterar o código principal.
Segurança Aprimorada: O acesso SSH foi restringido para apenas redes VPN, e as regras de saída foram limitadas, contribuindo para um ambiente mais seguro.
Automação: O uso de scripts de inicialização para instalar e configurar serviços na instância EC2 garante que a infraestrutura esteja pronta para uso imediatamente após a criação.


#### Instruções de Uso

Pré-requisitos
Terraform: Certifique-se de ter o Terraform instalado. Você pode baixar a versão mais recente em terraform.io.

Conta na AWS: Você precisa de uma conta na AWS com permissões adequadas para criar os recursos necessários.

Configuração das Credenciais AWS: As credenciais da AWS devem estar configuradas em seu ambiente. Você pode usar o arquivo ~/.aws/credentials ou configurar as variáveis de ambiente AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY.

Passos para Inicializar e Aplicar a Configuração Terraform
Clone o repositório:

```bash
git clone <URL_DO_REPOSITORIO> && cd <NOME_DA_PASTA>
```

Inicialize o Terraform:

```bash
terraform init
```

Valide a configuração:
```bash
terraform validate
```

Aplique a configuração:
```bash
terraform apply
```
Revise as alterações propostas e confirme a aplicação.

Acesse a Instância EC2:

Após a criação, você pode acessar a instância EC2 usando a chave privada gerada. Lembre-se de permitir o acesso SSH a partir da sua rede VPN.







## Arquivo main.tf Modificado


1. uma primeira sugestão segura é apontar o tráfego SSH para uma VPN que a empresa já utiliza. Ao implementar uma VPN, o tráfego SSH pode ser restrito apenas aos endereços IP gerados pela própria VPN, reduzindo a exposição ao tráfego externo e fornecendo uma camada adicional de autenticação e criptografia.. (linha 92)

2. Desabilitar SSH Root Login:
Para impedir que o usuário root faça login via SSH, é necessário ajustar a configuração SSH dentro do arquivo /etc/ssh/sshd_config. Você pode incluir esse ajuste no user_data da instância EC2.(linha 147)

3. Configurar um Firewall:
A AWS já aplica regras de segurança, mas você pode adicionar um firewall no nível do sistema operacional, como o ufw (Uncomplicated Firewall). Esse firewall pode ser configurado para restringir o tráfego SSH, HTTP, ou outros serviços conforme necessário.(linha 153)

2. Descrição Técnica e Resultados Esperados
Segurança Melhorada:

O acesso SSH foi restrito a uma faixa específica de IPs da VPN (tanto IPv4 quanto IPv6).
Foi desabilitado o login root via SSH, forçando a utilização de um usuário padrão mais seguro.
O tráfego de saída foi limitado a portas essenciais (HTTP, HTTPS e DNS), reduzindo a superfície de ataque.
Automação com Nginx:

O servidor Nginx será instalado e iniciado automaticamente, e configurado para reiniciar com o sistema.
Isso torna o ambiente pronto para receber tráfego web (HTTP), eliminando a necessidade de configuração manual após a criação da instância.

- **Segurança:** A regra de segurança para SSH permite acesso de qualquer lugar (0.0.0.0/0), o que pode representar um risco de segurança. Idealmente, o tráfego SSH deveria ser limitado a um IP ou range de IPs confiáveis ou.
