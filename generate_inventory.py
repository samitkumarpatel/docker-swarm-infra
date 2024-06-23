import json

# Load Terraform output JSON file
with open('terraform_output.json') as f:
    terraform_output = json.load(f)

# Extract manager and worker IPs
manager_ip = terraform_output['manager_public_ip']['value']
worker_ips = terraform_output['worker_public_ips']['value']

# Create the inventory content
inventory_content = "[manager]\n"
inventory_content += f"{manager_ip}\n\n"
inventory_content += "[worker]\n"
for i, ip in enumerate(worker_ips):
    inventory_content += f"{ip}\n"

# Write the inventory content to a file
with open('inventory.ini', 'w') as f:
    f.write(inventory_content)

print("Inventory file generated successfully.")
