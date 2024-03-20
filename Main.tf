provider "aws" {
  region = "votre_region"
}
resource "aws_security_group" "prometheus_grafana_sg" {
  name        = "prometheus_grafana_sg"
  description = "Security group for Prometheus and Grafana instance"
  
  // Autoriser l'accès SSH depuis n'importe où
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  // Autoriser l'accès HTTP depuis n'importe où
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Autoriser l'accès HTTP depuis n'importe où
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  // Autoriser l'accès HTTP depuis n'importe où
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  // Autoriser l'accès sortant vers n'importe où
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "docker_jenkins_sg" {
  name        = "docker_jenkins_sg"
  description = "Security group for Docker and Jenkins instance"
  
  // Autoriser l'accès SSH depuis n'importe où
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  // Autoriser l'accès HTTP depuis n'importe où
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  // Autoriser l'accès HTTP depuis n'importe où
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  // Autoriser l'accès sortant vers n'importe où
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "Prometheus-Grafana" {
    ami = "ami-0c7217cdde317cfec"
    instance_type = "t2.medium"

    tags {
        Name = "Prometheus-Grafana"}

    user_data = <<-EOF
#!/bin/bash

# Création de l'utilisateur prometheus
sudo useradd --system --no-create-home --shell /bin/false prometheus

# Téléchargement et installation de Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.47.1/prometheus-2.47.1.linux-amd64.tar.gz
tar -xvf prometheus-2.47.1.linux-amd64.tar.gz
cd prometheus-2.47.1.linux-amd64/
sudo mkdir -p /data /etc/prometheus
sudo mv prometheus promtool /usr/local/bin/
sudo mv consoles/ console_libraries/ /etc/prometheus/
sudo mv prometheus.yml /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /etc/prometheus/ /data/

# Configuration de l'unité systemd pour Prometheus
sudo tee /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/data --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries --web.listen-address=0.0.0.0:9090 --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

# Activation et démarrage de Prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Création de l'utilisateur node_exporter
sudo useradd --system --no-create-home --shell /bin/false node_exporter

# Téléchargement et installation de Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter*

# Configuration de l'unité systemd pour Node Exporter
sudo tee /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
EOF

# Activation et démarrage de Node Exporter
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
EOF

#Utilisation du groupe de sécurité "prometheus_grafana_sg"
vpc_security_group_ids = [aws_security_group.prometheus_grafana_sg.id]
}








resource "aws_instance" "instance_docker_jenkins" {
  ami           = "ami-xxxxxxxxxxxxx" // Remplacer ami-xxxxxxxxxxxxx par l'AMI d'Ubuntu 22.04
  instance_type = "t2.micro"
  tags = {
    Name = "instance_docker_jenkins"
  }
  user_data = <<-EOF

#!/bin/bash

# Mise à jour et installation des dépendances
sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git

# Installation de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable'
sudo apt update && sudo apt install -y docker-ce

# Démarrage et activation de Docker
sudo systemctl enable docker
sudo systemctl start docker

# Installation de Docker Compose
sudo apt install -y docker-compose

# Installation de git
sudo apt install -y git
EOF

#Utilisation du groupe de sécurité "docker_jenkins_sg"
vpc_security_group_ids = [aws_security_group.docker_jenkins_sg.id]
}