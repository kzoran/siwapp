I managed to run the new version of SIWAPP invoice APP (Elixir version) with PostgreSQL This is working on Ubuntu 24.04
I am sharing the fully automated installation script, which can be used in any environment:

Requirements:
1) 8 Virtual Machines: For example, on AWS, t3.micro instances (2 vCPU, 1GB Memory, 8GB Disk) work well. These VMs must have Internet access.
2) SSH Access: You need to be able to SSH into the private IPs of all 8 VMs using your SSH key from the machine where you will start the installation.
3) Configuration: Update only the "invoice-install-all.sh" file with the necessary server IPs and hostnames.
4) Installation: Run "bash ./invoice-install-all.sh" to begin the installation process.

Default Credentials:
Username: demo@example.com
Password: secretsecret 

Architecture:
User → app-lb (80, 443) → 3 x app (8080, 8443) → db-lb (5432) → 3 x db (5432, with replication)


SIWAPP Client Auto Traffic Generator:
On Ubuntu Server/Desktop acting as client copy the file to "siwapp_client_generate_traffic.sh" and run the
sudo bash siwapp_client_generate_traffic.sh <IP/Domain>