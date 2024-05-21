# Snipe-IT Azure Infrastructure Deployment with Terraform

This Terraform plan sets up the necessary resources in Azure for deploying Snipe-IT, an open-source IT asset management system. The resources created include a Resource Group, Virtual Network, Subnet, MySQL database, Storage Account, and Web App for hosting Snipe-IT.

## Prerequisites

Before you begin, ensure you have the following:

- [Terraform](https://www.terraform.io/downloads.html) installed on your local machine.
- An Azure account with the necessary permissions to create resources.
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated.
- Service Principal credentials for Terraform to use (App ID, Tenant ID, and Client Secret).

## Configuration

### Service Principal

Set up the Service Principal credentials as environment variables:

```bash
export AZURE_TENANT_ID=<your-tenant-id>
export AZURE_CLIENT_ID=<your-client-id>
export AZURE_CLIENT_SECRET=<your-client-secret>
```

### Terraform Variables

Edit the `main.tf` file or create a `terraform.tfvars` file to configure the following variables as needed:

- `app_name`: Name of the application (default: `assets-inventory-company`).
- `app_url`: URL for the application (default: `https://assets.inventory.company.com`).

## Deployment

### Step-by-Step Deployment

This Terraform plan automates the provisioning of the following resources:

1. **Resource Group**: Creates a resource group for organizing all resources.
2. **Virtual Network and Subnet**: Creates a virtual network and subnet for network isolation.
3. **Azure MySQL PaaS Instance**: Provisions a MySQL database instance.
4. **Azure Storage Account**: Creates a storage account for storing Snipe-IT files and logs.
5. **Azure Web App**: Sets up a web app for hosting the Snipe-IT Docker container.

### Detailed Steps

1. **Initialize and Apply Terraform Plan**

    Initialize Terraform:

    ```bash
    terraform init
    ```

    Plan the deployment:

    ```bash
    terraform plan
    ```

    Apply the Terraform plan:

    ```bash
    terraform apply
    ```

2. **MySQL Database Setup**

    The Terraform plan will create an Azure Database for MySQL flexible server with the specified configurations:
    - MySQL instance name
    - Region
    - Workload type
    - Username and password

    After the instance is created, the plan will also:
    - Create an empty database `snipe-it`
    - Set the following MySQL server parameters to `OFF` to avoid migration issues:
      - `innodb_buffer_pool_load_at_startup`
      - `innodb_buffer_pool_dump_at_shutdown`
      - `sql_generate_invisible_primary_key`

3. **Storage Account Setup**

    The Terraform plan will provision a storage account with the following configurations:
    - Storage account name
    - Region
    - Public access settings

    It will also create:
    - A file share called `snipeit` for storing the SSL certificate
    - A file share called `snipeit-logs` for storing application logs

    The plan will aslo upload the DB's `DigiCertGlobalRootCA.crt.pem` SSL certificate to the file share automatically.
   
5. **Web App Setup**

    The Terraform plan will set up a web app with the following configurations:
    - App name
    - Docker container settings (image: `snipe/snipe-it:latest`)
    - Pricing tier (Basic B1)

    It will also configure path mappings for Azure Storage:
    - Mount the file share `snipeit` to `/var/lib/snipeit`
    - Mount the file share `snipeit-logs` to `/var/www/html/storage/logs`

    Additionally, it will set the necessary application settings:
    - `MYSQL_DATABASE`
    - `MYSQL_USER`
    - `MYSQL_PASSWORD`
    - `DB_CONNECTION`
    - `MYSQL_PORT_3306_TCP_ADDR`
    - `MYSQL_PORT_3306_TCP_PORT`
    - `DB_SSL_IS_PAAS`
    - `DB_SSL`
    - `DB_SSL_CA_PATH`
    - `APP_URL`
    - `APP_KEY`
    - `MAIL_DRIVER`
    - `MAIL_ENV_ENCRYPTION`
    - `MAIL_PORT_587_TCP_ADDR`
    - `MAIL_PORT_587_TCP_PORT`
    - `MAIL_ENV_USERNAME`
    - `MAIL_ENV_PASSWORD`
    - `MAIL_ENV_FROM_ADDR`
    - `MAIL_ENV_FROM_NAME`
    - `APP_DEBUG`

6. **Docker Compose Configuration**

    The Terraform plan will configure the web app to use Docker Compose with the following configuration:

    ```yaml
    version: "3"

    services:
      snipe-it:
        image: snipe/snipe-it:latest
        volumes:
          - snipeit:/var/lib/snipeit
          - snipeit-logs:/var/www/html/storage/logs

    volumes:
      snipeit:
        external: true
      snipeit-logs:
        external: true
    ```

7. **Finalize Deployment**

    After all resources are provisioned and configured, the web app will restart, and you can access the Snipe-IT setup wizard via the URL of the web app.


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

- [Snipe-IT](https://snipeitapp.com/) for providing the open-source IT asset management system.
- [Terraform](https://www.terraform.io/) for infrastructure as code tooling.
- [Azure](https://azure.microsoft.com/) for cloud services.