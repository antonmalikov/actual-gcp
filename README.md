# actual-gcp
Actual Budget hosted on Google Cloud's always free tier

## Background
The goal of this repository is to deploy [Actual Budget][1] running on [Google Cloud's][2] [Free Tier][3], using the Compute Engine service. This setup utilizes [Terraform][4] to deploy and automatically configure the cloud infrastructure. Some manual steps may still need to be taken, but I've tried to remove as many as possible and document the rest.

Some notes about the architecture of this setup:

* The Compute Engine instance is deployed using Google's [Container Optimized OS][5] image and the applications run within this instance using [Docker][6].
* [DuckDNS][7] is used to provide a free subdomain for DNS resolution. If you own your own domain, you should be able to still use most of this configuration, though changes would need to be made. What those changes are have not been vetted or tested by me, and are outside the scope of this documentation.
* [Caddy][8] is used as a reverse proxy and for automatic TLS certificate management.
* [Terraform state][9] management is being handled by [HCP Terraform (formerly Terraform Cloud)][10], though you could opt to store your state file elsewhere if you want to (and feel comfortable doing so). Doing so is outside the scope of this documentation.

**Disclaimer**: While I've attempted to ensure that all cloud infrastructure being deployed is part of GCP's free tier, you are ultimately responsible for your own cloud spend. The Terraform code sets up an adjustible monthly billing alert to help mitigate risk of unexpected cloud costs, but it is your responsibility to monitor your cloud account.

[1]: https://actualbudget.com/
[2]: https://cloud.google.com
[3]: https://cloud.google.com/free/docs/free-cloud-features?_gl=1*16i0xkv*_up*MQ..&gclid=EAIaIQobChMItuHQrcyPiQMVFUL_AR2RuhIpEAAYASAAEgKEkPD_BwE&gclsrc=aw.ds#free-tier-usage-limits
[4]: https://www.terraform.io
[5]: https://cloud.google.com/container-optimized-os/docs
[6]: https://www.docker.com
[7]: https://www.duckdns.org/
[8]: https://caddyserver.com/
[9]: https://developer.hashicorp.com/terraform/language/state
[10]: https://app.terraform.io
[11]: https://cloud.google.com/sdk/docs/install
[12]: https://developer.hashicorp.com/terraform/install
[13]: https://cloud.google.com/architecture/best-practices-vpc-design#custom-mode
[14]: https://developer.hashicorp.com/terraform/tutorials/cloud-get-started/cloud-login
[15]: https://git-scm.com/downloads/win
[16]: https://cloud.google.com/billing/docs/resources/currency#list_of_countries_and_regions
[17]: https://actualbudget.com/docs/overview/getting-started/

## Pre-requisites
* A [Google Cloud][2] account
* A free [HCP Terraform][10] account (unless you want to host your state locally or elsewhere)
* A free [DuckDNS][7] subdomain
* The [Google Cloud CLI][11] tools installed
* [Terraform][12] installed

## Instructions
1. If you haven't already, create your [DuckDNS][7] subdomain and make note of your authentication token.
    * ![DuckDNS Example](./readme_resources/ddns.png)
2. If you haven't already, create your organization, project (unless you're using the Default project), and workspace in [HCP Terraform][10]. This repository assumes you've created your workspace using the CLI-Driven Workflow, but you can choose one of the other methods if you're comfortable adapting the instructions to accommodate it.
    * ![HCP Terraform New Workspace](./readme_resources/hcp_tf_new_workspace.png)
3. Within your workspace, navigate to Settings > General and scroll down to Execution Mode. Set it to "Local (Custom)". This will ensure that you can execute Terraform commands at the command line. By default, the workspace will be set to your Organization Default, which may already be set to Local. If your Organization Default is Local, you don't necessarily need to force the workspace to Local, but it also won't hurt to do so. Additionally, if you are deviating from these instructions and opting to choose to run Terraform within HCP Terraform and not on your local machine, you can ignore this step and select your desired Execution Mode for your custom setup.
    * ![HCP Terraform Execution Mode](./readme_resources/hcp_tf_execution_mode.png)
4. *Optional* - Run the following command to create an SSH public/private key-pair (if on Windows, you may need to [install Git][15] first):
    * `ssh-keygen`
    * **Note** - This will be used for SSH key-pair authentication when connecting directly, without the use of the Google SSH proxy. This configuration disables direct SSH access by default, though a firewall rule does get created to allow it. It is included in case short-term "break glass" / emergency access is needed.
5. Clone this repository to your machine (or create a fork and clone your fork) and open a terminal session into the repository's directory.
6. Run the following command to initialize your Google Cloud command line tools: 
    * `gcloud init`
7. Run the following command to make your user credentials available to Application Default Credentials (ADC):
    * `gcloud auth application-default login`
8. Run the following command to enable the API services necessary for Terraform to run and configure the rest of the environment:
    * `gcloud services enable cloudresourcemanager.googleapis.com`
    * `gcloud services enable serviceusage.googleapis.com`
    * `gcloud services enable cloudbilling.googleapis.com`
9. If this is a new Google Cloud environment, I recommend running the following commands to delete the default networking configuration, as new configurations will be deployed via Terraform:
    * `gcloud compute firewall-rules list`
    * For each firewall rule listed, run `gcloud compute firewall-rules delete rulename`
    * `gcloud compute networks delete default`
    * If you already have resources active using the default VPC, skip this step and update the Terraform code to remove the new 'google_compute_network' and 'google_compute_route' resources, as well as modifying the network for the 'google_compute_firewall' and 'google_compute_instance' resources.
    * Deleting the default network and using a custom network helps align with [documented best-practices regarding VPC design][13].
10. We're now ready to begin configuring our local Terraform environment. Run the following command to [authenticate with HCP Terraform][14]:
    * `terraform login`
11. Make the following updates to the following files in the repository:
    * Update `backend.tf` with your organization and workspace names from HCP Terraform.
    * Create a file named `sensitive.auto.tfvars` and create the following variables:
        * actual_fqdn - The fully-qualified domain name you want to use for your Actual Budget server. This can either be the same value as your DuckDNS subdomain (i.e. "example.duckdns.org"), or a subsite within it (i.e. "budget.example.duckdns.org")
        * billing_account_name = "your_billing_account_name" - This defaults to "My Billing Account", so this only needs defined if your billing account name is something else.
            * If you're not sure what your billing account name is, run the following command to list your billing accounts:
                `gcloud billing accounts list`
        * billing_alert_currency_code = "[your_currency_code][16]" - This isn't really a sensitive variable, but to simplify things, we can put it in the same ".auto.tfvars" file. This defaults to "USD", so this only needs defined if you're using a different currency.
        * billing_alert_amount = "the_amount_you_want" - This isn't really a sensitive variable, but to simply things, we can put it in the same ".auto.tfvars" file. This defaults to "5", so this only needs defined if you want to set a different billing alert threshold.
        * duckdns_subdomains = "your_subdomain" - Values captured in Step #1.
        * duckdns_token = "your_duckdns_token" - Values captured in Step #1.
        * gcp_billing_project_name = The name of your GCP billing project. This may be the same as your GCP project.
        * gcp_project_name = The name of your GCP project.
        * gcp_region = The GCP region you wish your workload to run in (for example, us-central1). Keep in mind [only certain regions are eligible for the always-free Compute Engine instance][3].
        * gcp_zone = The zone within the GCP region you want to use (for example, us-central1-c).
        * public_key_path - The path on your local machine to the SSH public key that was generated in Step #2 (if it was named something other than the default value defined in `compute-variables.tf`)
        * user = "your_google_username" - It should be your Google username without the "@gmail.com". If you use the SSH proxy to login from the GCP console, it will log you in automatically as this user.
        * **Note** - The `.gitignore` file is configured to ignore any *.auto.tfvars files. Be extremely cautious with what variable values you allow to be pushed to your source control (Git) repository.
        * **Note** - You could also define these variables within HCP Terraform if you want to have your Terraform actions performed there instead of your local command line.
        * ![Example Variables](./readme_resources/variable_values.png)
12. Run the following command to initiate Terraform:
    *  `terraform init`
13. Run the following command to execute a "plan" operation, where we can inspect what Terraform operations are expected to happen when the "apply" operation happens:
    *  `terraform plan`
14. Once you've reviewed the output of the "plan" operation and are ready to deploy the infrastructure, run the following command and confirm when prompted:
    * `terraform apply`
15. *Optional* - Post-deployment validation:
    * Once the "apply" operation has completed, navigate to the Google Cloud web console and inspect the new virtual machine.
        * ![Provisioned VM](./readme_resources/gcp_post_deployment.png)
    * **Note** - You can also run the following Google Cloud command to validate the new virtual machine:
        * `gcloud compute instances list`
        * `gcloud compute instances describe containerhost01`
    * **Note** - If you login to your DuckDNS account, you should see the IP address for your subdomain has been updated with the public IP address of your virtual machine.
    * Click the SSH button in the Google Cloud console. Once connected, run `docker ps -a`. We should see three containers running:
        * ![Docker processes](./readme_resources/docker_ps.png)
        * If the Google Cloud SSH proxy isn't working, temporarily update the "container_host_network_tags" variable in `terraform.tfvars` and re-run `terraform apply` to add the "allow-ssh" tag, which will allow SSH from your local machine. I recommend removing that network tag and re-running `terraform apply` when finished to disable direct SSH access again.
    * If the three containers aren't running, you can inspect their associated systemctl services using the following commands:
        * `systemctl status actual`
        * `systemctl status caddy`
        * `systemctl status duckdns`
    * If the containers are running, but things aren't working as-expected, use the following commands to inspect the container logs to further troubleshoot:
        * `docker logs actual_server`
        * `docker logs caddy`
        * `docker logs duckdns`
    * Run the following command to ensure the applications' "data" directory has been mounted onto the Persistent Disk (/dev/sdb):
        * ![lsblk output](./readme_resources/lsblk_output.png)
        * **Important** This part of the configuration is critical to application data persisting across virtual machine reboots.
16. Open your web browser and navigate to the fully-qualified domain name you set for the value of the "actual_fqdn" variable (i.e. ht<span>tps://</span>budget.example.duckdns.org). You should see the Actual Budget login page. You're now ready to setup your budget. Follow [Actual Budget's Getting Started][17] page for next steps.
    * ![Actual Budget login](./readme_resources/actual_login_page.png)

## Terraform Configuration Reference

This section describes every file in the Terraform configuration and explains the logic behind each block.

---

### `backend.tf` — Remote State Backend

```hcl
terraform {
  cloud {
    organization = "your-organization"
    workspaces {
      name = "your-workspace"
    }
  }
}
```

**Purpose:** Configures where Terraform stores its [state file](https://developer.hashicorp.com/terraform/language/state).

* The `terraform { cloud { … } }` block tells Terraform to use **HCP Terraform** (formerly Terraform Cloud) as the remote backend instead of a local file.
* `organization` — the name of your HCP Terraform organization.
* `workspaces.name` — the specific workspace within that organization that holds the state for this deployment.
* Using remote state means the `terraform.tfstate` file is never written to disk locally, which keeps secrets out of your local filesystem and allows multiple collaborators to safely share state.

---

### `main.tf` — Google Provider

```hcl
provider "google" {
  project               = var.gcp_project_name
  region                = var.gcp_region
  zone                  = var.gcp_zone
  user_project_override = true
  billing_project       = var.gcp_billing_project_name
}
```

**Purpose:** Declares and configures the [Google Cloud Terraform provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs).

* `project` — the default GCP project ID used for all resources.
* `region` / `zone` — the default region and zone for resources that require them (e.g. compute disks, VM instances).
* `user_project_override = true` — instructs the provider to bill API quota against the `billing_project` rather than the resource's project. This is required when the GCP service account making calls belongs to a different project than the one being operated on.
* `billing_project` — the GCP project against which API quota is billed.

---

### `terraform.tfvars` — Default Variable Values

```hcl
vm_size                     = "e2-micro"
vm_image_family             = "cos-117-lts"
vm_image_project            = "cos-cloud"
container_host_network_tags = ["allow-ssh-proxy", "https-server", "http-server"]
project_enabled_services    = [...]
```

**Purpose:** Provides non-sensitive default values for input variables that are the same for every deployment.

* `vm_size = "e2-micro"` — selects the `e2-micro` machine type, which qualifies for GCP's always-free Compute Engine tier.
* `vm_image_family = "cos-117-lts"` / `vm_image_project = "cos-cloud"` — pins the VM to the **Container-Optimized OS** LTS image family so that the latest patched image in that family is always used.
* `container_host_network_tags` — applies three network tags to the VM: `allow-ssh-proxy` (IAP SSH), `https-server` (HTTPS inbound), and `http-server` (HTTP inbound). Firewall rules are scoped to these tags.
* `project_enabled_services` — the list of GCP APIs that must be enabled before any other resource can be created:
  * `cloudbilling.googleapis.com` — required to manage billing budgets.
  * `cloudresourcemanager.googleapis.com` — required to look up project metadata.
  * `compute.googleapis.com` — required for all Compute Engine resources.
  * `iam.googleapis.com` — required to create and manage service accounts.
  * `networkmanagement.googleapis.com` — required for VPC and firewall management.

---

### `project-variables.tf` — Project Variable Declarations

**Purpose:** Declares the input variables that describe the target GCP environment.

| Variable | Type | Description |
|---|---|---|
| `gcp_project_name` | string | The GCP project in which all resources are created. |
| `gcp_billing_project_name` | string | The GCP project used for API quota billing (see `main.tf`). |
| `gcp_region` | string | The GCP region (e.g. `us-central1`). Must be in an always-free-eligible region. |
| `gcp_zone` | string | The zone within the region (e.g. `us-central1-c`). |
| `project_enabled_services` | list(string) | The GCP APIs to enable (defaulted in `terraform.tfvars`). |

---

### `project-data.tf` — Project Data Source

```hcl
data "google_project" "project" {}
```

**Purpose:** Fetches metadata about the current GCP project (determined by the provider's `project` attribute).

* The resulting `data.google_project.project` object exposes fields like `.id` (the numeric project ID) and `.project_id` (the string name), which are referenced by other resources — notably `project.tf` — without having to hard-code them.

---

### `project.tf` — Enable GCP APIs

```hcl
resource "google_project_service" "project" {
  for_each = toset(var.project_enabled_services)
  project  = data.google_project.project.id
  service  = each.key

  timeouts { create = "30m"; update = "40m" }
  disable_on_destroy = false
}
```

**Purpose:** Enables each GCP API listed in `project_enabled_services`.

* `for_each = toset(var.project_enabled_services)` — iterates over the list of service names, converting it to a set so Terraform treats each service as an independent resource.
* `service = each.key` — the API identifier (e.g. `compute.googleapis.com`) for the current iteration.
* `timeouts` — GCP API enablement can be slow; the extended timeouts prevent Terraform from failing on a slow API propagation.
* `disable_on_destroy = false` — keeps the APIs enabled even when `terraform destroy` is run, preventing accidental disruption to other resources that may depend on them.

---

### `billing-variables.tf` — Billing Variable Declarations

**Purpose:** Declares variables that control the billing budget alert.

| Variable | Type | Default | Description |
|---|---|---|---|
| `billing_account_name` | string | `"My Billing Account"` | Display name of the GCP billing account. |
| `billing_alert_currency_code` | string | `"USD"` | ISO 4217 currency code for the budget. |
| `billing_alert_amount` | string | `"5"` | Monthly spend threshold (in the chosen currency) that triggers the alerts. |

---

### `billing-data.tf` — Billing Account Data Source

```hcl
data "google_billing_account" "billing_account" {
  display_name = var.billing_account_name
}
```

**Purpose:** Looks up the GCP billing account by its human-readable display name so its ID can be referenced in `billing.tf` without being hard-coded.

---

### `billing.tf` — Monthly Budget Alert

```hcl
resource "google_billing_budget" "budget" {
  billing_account = data.google_billing_account.billing_account.id
  display_name    = "Monthly Budget Alert"

  amount {
    specified_amount {
      currency_code = var.billing_alert_currency_code
      units         = var.billing_alert_amount
    }
  }

  threshold_rules { threshold_percent = 0.5  }
  threshold_rules { threshold_percent = 0.9  }
  threshold_rules { threshold_percent = 1    }
  threshold_rules { threshold_percent = 1.5  }
}
```

**Purpose:** Creates a GCP billing budget to alert when monthly spending approaches or exceeds the configured threshold.

* `billing_account` — links the budget to the billing account fetched in `billing-data.tf`.
* `amount.specified_amount` — sets the fixed monetary limit (e.g. $5 USD by default).
* Four `threshold_rules` fire email notifications to the billing account's administrators when spending reaches **50 %**, **90 %**, **100 %**, and **150 %** of the budget. The 150 % rule is an overage alert in case spending continues past the limit.

---

### `compute-variables.tf` — Compute Variable Declarations

**Purpose:** Declares input variables that describe the VM, the OS image, and the application-level configuration.

| Variable | Type | Default | Description |
|---|---|---|---|
| `actual_fqdn` | string | *(required)* | The fully-qualified domain name for the Actual Budget server; used by Caddy to obtain a TLS certificate. |
| `container_host_network_tags` | list(string) | *(required)* | Network tags applied to the VM to target firewall rules. |
| `duckdns_subdomains` | string | *(required)* | Comma-delimited DuckDNS subdomain(s) to update with the VM's public IP. |
| `duckdns_token` | string | *(required)* | Secret authentication token for the DuckDNS API. |
| `public_key_path` | string | `~/.ssh/id_gcp_ed25519.pub` | Path to the SSH public key on the local machine. |
| `public_key` | string | `""` | Fallback inline SSH public key (used when running in HCP Terraform where the local filesystem is unavailable). |
| `user` | string | *(required)* | Google account username; used as the OS-level login name for SSH. |
| `vm_image_family` | string | *(required)* | Container-Optimized OS image family (e.g. `cos-117-lts`). |
| `vm_image_project` | string | *(required)* | GCP project that owns the OS image (`cos-cloud`). |
| `vm_size` | string | *(required)* | Compute Engine machine type (e.g. `e2-micro`). |

---

### `compute-data.tf` — Container-Optimized OS Image Data Source

```hcl
data "google_compute_image" "container_optimized" {
  family  = var.vm_image_family
  project = var.vm_image_project
}
```

**Purpose:** Resolves the latest published image from the specified Container-Optimized OS image *family*. Using a family name (rather than a specific image name) means that every `terraform apply` automatically picks up the most recent patched image, keeping the VM's OS up to date.

---

### `compute.tf` — Service Account, Disks, and VM Instance

#### Service Account

```hcl
resource "google_service_account" "container_host" {
  account_id   = "container-host-sa"
  display_name = "Custom SA for Container Host VM Instance"
}
```

Creates a dedicated, least-privilege service account for the VM. Following Google's recommendation, the account is granted `cloud-platform` scope and permissions are assigned via IAM roles, rather than using the broad default compute service account.

#### Boot Disk

```hcl
resource "google_compute_disk" "container_host_boot_disk" {
  name  = "container-host-boot-disk"
  type  = "pd-standard"
  image = data.google_compute_image.container_optimized.self_link
  size  = 10
  labels = { managed_by = "terraform" }
  physical_block_size_bytes = 4096
}
```

Creates a **10 GB standard persistent disk** pre-loaded with the Container-Optimized OS image. Separating the disk definition from the instance means the disk persists independently, allowing the VM to be replaced (e.g. for OS upgrades) without disk destruction.

#### Data Disk

```hcl
resource "google_compute_disk" "container_host_data_disk" {
  name = "container-host-data-disk"
  type = "pd-standard"
  size = 20
  labels = { managed_by = "terraform" }
  physical_block_size_bytes = 4096
}
```

Creates a **20 GB standard persistent disk** for application data. This disk is separate from the boot disk so that Actual Budget's financial data and Caddy's TLS certificates survive VM rebuilds or OS updates. The cloud-init script (in `locals.tf`) formats and mounts this disk on first boot.

#### VM Instance

```hcl
resource "google_compute_instance" "container_host" {
  name         = "containerhost01"
  machine_type = var.vm_size
  allow_stopping_for_update = true
  tags         = var.container_host_network_tags
  ...
}
```

Creates the virtual machine itself.

* `allow_stopping_for_update = true` — allows Terraform to stop and restart the VM when certain properties (e.g. machine type) change, rather than forcing a destroy-and-recreate.
* `tags` — network tags that determine which firewall rules apply to this VM.
* `boot_disk` / `attached_disk` — attaches the two persistent disks defined above.
* `network_interface` — places the VM in the custom VPC and grants it an ephemeral public IP using the `STANDARD` network tier (cheaper than `PREMIUM` and sufficient for this use case).
* `metadata.ssh-keys` — injects the operator's SSH public key, supporting both local-file and inline-string modes so the config works both from a developer's workstation and from HCP Terraform's remote execution environment.
* `metadata.user-data` — passes the cloud-init YAML (from `locals.tf`) to the VM, which the OS executes on first boot to configure the entire application stack.
* `scheduling` — sets the VM to a non-preemptible, automatically-restarted `STANDARD` provisioning model, maximizing uptime without incurring spot/preemptible pricing risk.
* `service_account` — attaches the dedicated service account created above with `cloud-platform` scope.

---

### `locals.tf` — Cloud-Init Configuration

**Purpose:** Builds the **cloud-init** YAML document that is injected into the VM via the `user-data` metadata key. Cloud-init is executed by the OS on first boot (for setup) and via `bootcmd` on every subsequent boot (for mount tasks). The document is assembled using Terraform's `yamlencode` function so that indentation and escaping are always correct.

#### `write_files` — File System Provisioning

Five files are written to the VM before any commands run:

| File | Description |
|---|---|
| `/etc/systemd/system/duckdns.service` | A **systemd unit** that runs the `linuxserver/duckdns` Docker container. On start it sends the VM's current public IP to the DuckDNS API to update the DNS record. The container is ephemeral (`--rm`) and runs once per service start. |
| `/etc/systemd/system/caddy.service` | A **systemd unit** that runs the `caddy:alpine` Docker container as a reverse proxy. It listens on port 443, uses the custom bridge network to reach the Actual container by name, and mounts the `Caddyfile`, TLS data, and config directories from the persistent data disk. |
| `/etc/systemd/system/actual.service` | A **systemd unit** that runs the `actualbudget/actual-server:latest` Docker container. It listens on the IPv6 loopback (`[::1]:5006`) on the bridge network so it is only reachable via the Caddy reverse proxy, not directly from the internet. Application data is mounted from the persistent data disk. |
| `/tmp/Caddyfile` | A minimal **Caddy configuration file** that enables gzip/zstd compression and proxies HTTPS requests for `var.actual_fqdn` to the `actual_server` container on port 5006. Caddy automatically obtains and renews TLS certificates for this domain via ACME/Let's Encrypt. |
| `/var/lib/cloud/scripts/per-instance/fs-prepare.sh` | A **one-time setup script** that formats the data disk as ext4, mounts it at `/mnt/disks/data`, creates the required directory structure for Caddy and Actual Budget, and copies the `Caddyfile` from `/tmp` to the persistent disk. The `per-instance` path ensures this script only runs once (on first boot), not on every reboot. |

#### `runcmd` — First-Boot Commands

Executed once, in order, after `write_files`:

1. `docker network create custom-bridge` — creates a Docker bridge network so that the Caddy and Actual containers can communicate by container name.
2. `systemctl daemon-reload` — reloads systemd so it recognises the new unit files.
3. `systemctl start caddy.service` — starts the Caddy reverse proxy.
4. `systemctl start actual.service` — starts the Actual Budget server.
5. `systemctl start duckdns.service` — triggers the first DuckDNS DNS update.

#### `bootcmd` — Every-Boot Commands

Executed on **every** boot, before `runcmd` and before the filesystem is fully set up:

1. `fsck.ext4 -tvy /dev/disk/by-id/google-persistent-disk-1` — checks and repairs the ext4 filesystem on the data disk.
2. `mkdir -p /mnt/disks/data` — ensures the mount point exists.
3. `mount -t ext4 -o nodev,nosuid …` — mounts the persistent data disk so that Caddy and Actual can find their data directories on every boot.
4. Additional `mkdir -p` commands recreate the sub-directory structure in case the mount point was empty.

---

### `network.tf` — VPC Network

```hcl
resource "google_compute_network" "vpc_network" {
  name = "vpc-network"
}
```

**Purpose:** Creates a custom-mode VPC network. GCP's default network comes with auto-generated subnets and firewall rules that are considered a security anti-pattern. By creating a dedicated VPC, all network topology is explicitly managed by Terraform, aligning with [GCP's VPC design best practices](https://cloud.google.com/architecture/best-practices-vpc-design#custom-mode). All other compute and firewall resources reference this network.

---

### `network-firewall.tf` — Firewall Rules

Four ingress firewall rules are defined, all on `vpc_network` at priority 1000. A rule only applies to VM instances that carry the matching network tag.

| Rule | Tag | Ports | Source | Purpose |
|---|---|---|---|---|
| `allow-https` | `https-server` | TCP 443 | `0.0.0.0/0` (internet) | Allows HTTPS traffic so Caddy can serve the Actual Budget web UI and handle ACME certificate challenges. |
| `allow-http` | `http-server` | TCP 80 | `0.0.0.0/0` (internet) | Allows HTTP traffic, which Caddy may use for ACME HTTP-01 challenge redirects before upgrading to HTTPS. |
| `allow-ssh-proxy` | `allow-ssh-proxy` | TCP 22 | `35.235.240.0/20` | Allows SSH only from **Google's Identity-Aware Proxy (IAP)** IP range, enabling browser-based SSH from the GCP console without exposing port 22 to the open internet. |
| `allow-ssh` | `allow-ssh` | TCP 22 | `0.0.0.0/0` (internet) | Allows SSH from anywhere. The `allow-ssh` tag is **not** in the default `container_host_network_tags`, so this rule is inactive unless the tag is temporarily added for emergency ("break-glass") access. |

---

## Updating Actual Server
There are a couple of ways you could use to try to update Actual Server to a newer version.

1. Re-run `terraform apply`. If a newer version of the Google Container Optimized OS image has been published, the virtual machine will be destroyed and re-deployed, pulling the latest version of the actualbudget/actual-server container during the re-deploy.
2. If you want to manually trigger an update, you can perform the following steps:
    * SSH into the virtual machine.
        * ![GCP Console SSH](./readme_resources/ssh_vm.png)
    * Issue the following commands:
        ```
        docker pull actualbudget/actual-server:latest
        sudo systemctl restart actual
        ```
        * ![Manual update container](./readme_resources/update_container.png)
    * Your server should now reflect the most recent version.
        * ![Version check](./readme_resources/actual_update.png)
