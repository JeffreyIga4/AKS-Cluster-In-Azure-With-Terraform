# AKS Cluster on Azure with Terraform (Service Principal + Key Vault)

## Overview

This project provisions an **Azure Kubernetes Service (AKS)** cluster using **Terraform**, following Infrastructure as Code (IaC) best practices.

The deployment uses a **Service Principal–based authentication model**, securely manages secrets using **Azure Key Vault**, and stores Terraform state remotely in **Azure Storage**. SSH access to AKS nodes is handled using **Terraform-generated keys**, with the private key stored securely in Key Vault.

The goal of this project is to demonstrate **real-world Azure infrastructure patterns**.

---

## Architecture


<img width="1536" height="1024" alt="EC6A1863-7752-4C06-8B0D-DE0C4E492476" src="https://github.com/user-attachments/assets/4e31225e-60f0-4dcf-a486-4656887b4327" />


### High-Level Flow

- Terraform is executed from a DevOps workstation
- Terraform state is stored remotely in Azure Storage
- A Service Principal is created in Entra ID
- Azure Key Vault stores sensitive secrets:
  - Service Principal client secret
  - AKS SSH private key
- AKS is provisioned using the Service Principal credentials
- SSH public key is injected into AKS nodes

---

## Components

### Terraform
- Provisions all Azure resources
- Uses a remote backend for state storage
- Generates SSH keys using `tls_private_key`
- Manages Azure RBAC assignments declaratively

### Azure Key Vault
- Stores sensitive secrets securely
- Uses Azure RBAC
- Secrets managed entirely by Terraform

### Service Principal (Entra ID)
- Created via Terraform
- Granted **Contributor** access at subscription scope
- Used by AKS for cluster authentication

### Azure Kubernetes Service (AKS)
- Deployed using Service Principal authentication
- Uses Terraform-generated SSH public key
- No hardcoded credentials or manual key handling

---

## Security Considerations

- No secrets are hardcoded
- No SSH keys are generated manually
- No sensitive files are committed to GitHub
- `terraform.tfvars` and `kubeconfig` are excluded via `.gitignore`
- Key Vault access is restricted using least-privilege RBAC roles

---

## Terraform State Management

- Terraform state is stored remotely in Azure Storage
- Prevents accidental state loss
- Enables reproducible deployments
- Avoids exposing sensitive outputs locally

---

## Challenges Faced & Solutions

Below are some of the challenges encountered and how they were resolved.

---

### 1. Key Vault `403 Forbidden` Errors

**Error**

- ForbiddenByRbac
- Caller is not authorized to perform action 'getSecret'


**Cause**
- Azure Key Vault uses **data-plane RBAC**
- Subscription-level roles do not grant secret access

**Solution**
- Identified Terraform execution identity using `azurerm_client_config`
- Assigned **Key Vault Secrets Officer** role via Terraform
- Added explicit dependencies to ensure RBAC is applied before secret creation

---

### 2. RBAC Breaking After `terraform destroy`

**Cause**
- Destroying Key Vault removes all RBAC assignments
- Manual role assignments were lost on rebuild

**Solution**
- Codified RBAC assignments in Terraform
- Ensured RBAC is recreated automatically on every `apply`
- Eliminated all manual Azure CLI role assignment steps

---

### 3. Secure SSH Key Management

**Problem**
- Manual SSH key handling is insecure and non-reproducible

**Solution**
- Generated SSH keys using Terraform `tls_private_key`
- Injected public key into AKS
- Stored private key securely in Azure Key Vault
- Never wrote SSH keys to disk or committed them to GitHub

---


