# Project Overview:
AWS infra using Terraform for **Continuous integration and continuous deployment (CI/CD)** using a powerful combination of Jenkins, Ansible, Docker, and GitHub Webhooks, all running on the RHEL9 AMI on AWS cloud platform.\
AMI ID used = ami-0b8c2bd77c5e270cf (RHEL-9.6.0_HVM_GA-20250423-x86_64-0-Hourly2-GP3)\
Final outcome of this pipeline is as follows:
1) AWS RHEL9.6 EC2
2) AWS components like VPC, SG, NACL, SubNet, RouteTable, IGW etc
3) if the terraform apply works fine you can login to Artifactory using URL http://<AWS_PUBLIC_IP>:8081/artifactory/
4) Default Artifactory id/password as admin/password
5) Below are some commonly used frequently used troubleshooting commands which you can use.

http://<AWS_PUBLIC_IP>:8081/artifactory

## To run this project on your side
### expectations
- terraform configured
- github configured
- AWS CLI configured

- Initial manual steps for creating Globally unique S3 bucket and DynamoDB lock table.
### ✅ Step 1: Create the S3 bucket (if not done already)
  ```
  aws s3api create-bucket 
  --bucket terraform-state-bucket-<AWS_ACCOUNT_ID> 
  --region us-east-1
  ```

### ✅ Step 2: Create the DynamoDB locking table (if needed)
```
  aws dynamodb create-table 
  --table-name terraform-lock-table 
  --attribute-definitions AttributeName=LockID,AttributeType=S 
  --key-schema AttributeName=LockID,KeyType=HASH 
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

### ✅ Step 3: Update the actual values in **backend.tf**: update the correct S3 bucket name. 
No need to update anything about terraform-lock-table, because that is already there.

### ✅ Step 4: Change the value in **terraform.tfvars**: change the link to your github URL. 
be sure to fork this repo into your project first.


### ✅ Step 5
```terraform init```

### ✅ Step 6
```Terraform plan```
<-- if you want to see what will be provisioned on AWS

### ✅ Step 7
```terraform apply```
<-- *be sure to type yes when prompted*

### ✅ Step 8 
When done Wait for EC2 instance and artifatory to come up fine on public ip

### ✅ Step 9 
Then kill ec2 and let it come up also fine on new public ip.
You can watch **github-project-logs** in cloud watch under log group

### Manual commands to check:
```aws s3 ls | grep your-terraform-state-bucket-<AWS_ACCOUNT_ID>```\
```aws dynamodb describe-table --table-name my-terraform-locks```

### docker commands\
```docker-compose -f /root/artifactory/docker-compose.yml up -d```\
```docker-compose down -v```\
```docker-compose up -d```\
```docker-compose stats```\

NOTE : Do not create the file db.properties. 
The Artifactory container will create thee file by itself from docker-compose.yml\ /var/opt/jfrog/artifactory/etc/db.properties
