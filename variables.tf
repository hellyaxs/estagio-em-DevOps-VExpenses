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

variable "instance_count" {
  description = "Número de instâncias EC2"
  type        = number
  default     = 1
}


variable "egress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
  }))

  default = [
    {
      description = "Allow HTTP traffic"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
    },
    {
      description = "Allow HTTPS traffic"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
    },
    {
      description = "Allow DNS traffic"
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
    }
  ]
}