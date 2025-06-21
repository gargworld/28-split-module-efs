WS infra using Terraform for **Continuous integration and continuous deployment (CI/CD)** using a powerful combination of Jenkins, Ansible, Docker, and GitHub Webhooks, all running on the RHEL9 AMI on AWS cloud platform.
AMI ID used = ami-0b8c2bd77c5e270cf (RHEL-9.6.0_HVM_GA-20250423-x86_64-0-Hourly2-GP3)
Final outcome f this pipeline is as follows:
1) AWS RHEL9.6 EC2
2) AWS components like VPC, SG, NACL, SubNet, RouteTable, IGW etc
3) if the terraform apply works fine you can login to Artifactory using URL http://<AWS_PUBLIC_IP>:8081/artifactory/
4) Default Artifactory id/password as admin/password
5) Below are some commonly used frequently used troubleshooting commands which you can use.

http://<AWS_PUBLIC_IP>:8081/artifactory/

# To run this project on your side
### expectations
- terraform configured
- github configured
- AWS configured


### Step 1
```terraform init```

### Step 2
```Terraform plan```
<-- if you want to see what will be provisioned on AWS

### Step 3
```terraform apply```
*be sure to type yes when prompted*

### When done and want to remove the provisioned infrastructure
```terraform destroy```

credit:
**originally forked from:** https://github.com/Keerthibb/Terraform-Jenkins-Ansible-Docker-CI-CD-Pipeline


**Manual commands :**

docker-compose -f /root/artifactory/docker-compose.yml up -d
docker-compose down -v
docker-compose up -d
docker-compose stats

openssl rand -hex 32 | tr -d "\n" > /data/artifactory/master.key
chown -R 1030:1030 /data/artifactory/master.key

docker volume rm artifactory_data
docker volume ls
docker volume inspect artifactory_data

chown -R 1030:1030 etc;chmod -R 775 etc

ansible-playbook -i inventory/hosts site.yml

curl -I http://<localhost>:8081/artifactory/

docker exec -it postgresql /bin/bash
docker exec -it artifactory pwd

docker logs --tail 100 -f artifactory

NOTE : Do not create this file db.properties. 
Artifactory container will create by itself from docker-compose.yml /var/opt/jfrog/artifactory/etc/db.properties
