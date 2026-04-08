[![N|Solid](./images/siwapp_logo.png)


**Project Evolution**

**Debian 13 Support**: Successfully refactored the environment to run smoothly on the latest Debian release.

**Enhanced Setup Script**: I’ve refined the installer to be more "state-aware." By introducing idempotent logic, the script can now pick up right where it left off. This makes the setup more robust and user-friendly, especially for those who might need to troubleshoot environmental issues mid-install. & it saves time :)

**Next Steps**: This lab will be used in CSW (Cisco Secure Workload) enviroment. I will create an ansible playbook to deploy CSW Agents 

**From Original Creator**: 
I managed to run the new version of SIWAPP invoice APP (Elixir version) with PostgreSQL This is working on ~~Ubuntu 24.04~~ Debian13
I am sharing the fully automated installation script, which can be used in any environment:

**Requirements**:
1) 8 Virtual Machines: For example, on AWS, t3.micro instances (2 vCPU, 1GB Memory, 8GB Disk) work well. These VMs must have Internet access.
2) SSH Access: You need to be able to SSH into the private IPs of all 8 VMs using your SSH key from the machine where you will start the installation.
3) Configuration: Update only the "invoice-install-all.sh" file with the necessary server IPs and hostnames.
4) Installation: Run "bash ./invoice-install-all.sh" to begin the installation process.

**Default Credentials**:
Username: demo@example.com
Password: secretsecret 

**Architecture**:
User → app-lb (80, 443) → 3 x app (8080, 8443) → db-lb (5432) → 3 x db (5432, with replication)


SIWAPP Client Auto Traffic Generator:
On Ubuntu Server/Desktop acting as client copy the file to "siwapp_client_generate_traffic.sh" and run the
sudo bash siwapp_client_generate_traffic.sh <IP/Domain>

## Contributors
Originally developed by Sujit Chandrapati, whose version is fully compatible with all public cloud environments
Refactoring for On-Premise (Debian 13) & Idempotent Installation by MiniMe
