# 🔐 Complete Guide: AWS S3 Configuration and Private Key Creation

**Last Updated**: January 9, 2026 at 10:08:34 AM EST (US Eastern Time)

---

This document provides a complete step-by-step guide for:
1. Configure the S3 bucket on AWS for the Hyperlane validator
2. Create private keys in hexadecimal format for Terra Classic, BSC, Ethereum, and Solana

**⚠️ IMPORTANT**: This guide uses **CLI (Command Line Interface) methods** to generate all private keys, following best practices and official Hyperlane documentation.

**Required CLI tools:**
- `terrad` - For Terra Classic (Cosmos)
- `cast` (Foundry) - For BSC and Ethereum (EVM)
- `solana-keygen` - For Solana (Sealevel)
- `openssl` - Alternative for generating random keys

---

## 📋 Index

1. [AWS S3 Configuration](#1-aws-s3-configuration)
   - [Prerequisites](#11-prerequisites)
   - [Create IAM User](#12-create-iam-user)
   - [Create S3 Bucket](#13-create-s3-bucket)
   - [AWS S3 Monthly Costs](#14-aws-s3-monthly-costs)
2. [Private Key Creation in Hex](#2-private-key-creation-in-hex)
   - [Terra Classic](#21-terra-classic)
   - [BSC (Binance Smart Chain)](#22-bsc-binance-smart-chain)
   - [Ethereum (ETH)](#23-ethereum-eth)
   - [Solana](#24-solana)
3. [JSON File Configuration](#3-json-file-configuration)
4. [Verification and Testing](#4-verification-and-testing)
5. [Troubleshooting](#5-troubleshooting)

---

## 1. AWS S3 Configuration

### 1.1. Prerequisites

- Active AWS account
- AWS CLI installed and configured
- Administrator or IAM permissions for S3 and IAM

### 1.2. Create IAM User

#### Step 1: Access IAM Console

1. Access: https://console.aws.amazon.com/iam/
2. In the left sidebar, click **"Users"**
3. Click the **"Add users"** button

#### Step 2: Configure User

1. **Username**: `hyperlane-validator`
2. Click **"Next"**
3. **DO NOT** select any policies yet
4. Click **"Next"** again
5. Click **"Create user"**

#### Step 3: Create Access Keys

1. Click on the newly created user
2. Go to the **"Security credentials"** tab
3. Scroll to **"Access keys"**
4. Click **"Create access key"**
5. Select **"Application running outside AWS"**
6. Click **"Next"**
7. (Optional) Add a description: "Hyperlane Validator Keys"
8. Click **"Create access key"**
9. **⚠️ IMPORTANT**: Copy and save in a secure location:
   - `Access key ID` (starts with `AKIA...`)
   - `Secret access key` (long string)
10. Click **"Done"**

#### Step 4: Configure IAM Permissions

1. Still on the user page, click **"Add permissions"**
2. Select **"Create inline policy"**
3. Click the **"JSON"** tab
4. Paste the following policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:DescribeKey",
        "kms:GetPublicKey",
        "kms:Sign",
        "kms:CreateAlias",
        "kms:ListAliases",
        "kms:ListKeys"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::hyperlane-validator-signatures-*",
        "arn:aws:s3:::hyperlane-validator-signatures-*/*"
      ]
    }
  ]
}
```

5. Click **"Next"**
6. **Policy name**: `HyperlaneValidatorPolicy`
7. Click **"Create policy"**

#### Step 5: Save Credentials to .env

```bash
cd /home/lunc/tc-hyperlane-validator

# Create .env file if it does not exist
cat > .env << EOF
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=us-east-1
EOF

# Protect the file
chmod 600 .env
```

**⚠️ IMPORTANT**: Replace the values with your actual Access Key ID and Secret Access Key.

### 1.3. Create S3 Bucket

#### Step 1: Access S3 Console

1. Access: https://s3.console.aws.amazon.com/s3/home?region=us-east-1
2. Click **"Create bucket"**

#### Step 2: Configure Bucket

1. **Bucket name**:
   ```
   hyperlane-validator-signatures-YOUR-NAME
   ```
   
   **Example:**
   ```
   hyperlane-validator-signatures-joao-terraclassic
   ```
   
   **⚠️ IMPORTANT**: 
   - The bucket name must be globally unique on AWS
   - Replace `YOUR-NAME` with a unique identifier (your name, username, etc.)
   - Use only lowercase letters, numbers, and hyphens

2. **AWS Region**: `US East (N. Virginia) us-east-1`

3. **Object Ownership**: `ACLs disabled (recommended)`

4. **Block Public Access settings**:
   - ⚠️ **UNCHECK** "Block all public access"
   - ✅ **CHECK** the box "I acknowledge that the current settings might result in this bucket and the objects within it becoming public"

5. **Bucket Versioning**: `Disable`

6. **Default encryption**: `Server-side encryption with Amazon S3 managed keys (SSE-S3)`

7. Click **"Create bucket"**

#### Step 3: Configure Bucket Policy

1. Click on the newly created bucket
2. Go to the **"Permissions"** tab
3. Scroll to **"Bucket policy"**
4. Click **"Edit"**

**Paste the following policy** (replace the values):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR-BUCKET-NAME",
        "arn:aws:s3:::YOUR-BUCKET-NAME/*"
      ]
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR-ACCOUNT-ID:user/hyperlane-validator"
      },
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
    }
  ]
}
```

**⚠️ Replace:**
- `YOUR-BUCKET-NAME` → Your bucket name (e.g., `hyperlane-validator-signatures-john-terraclassic`)
- `YOUR-ACCOUNT-ID` → Your AWS Account ID (12 digits)

**Complete example:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::hyperlane-validator-signatures-joao-terraclassic",
        "arn:aws:s3:::hyperlane-validator-signatures-joao-terraclassic/*"
      ]
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:user/hyperlane-validator"
      },
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::hyperlane-validator-signatures-joao-terraclassic/*"
    }
  ]
}
```

5. Click **"Save changes"**

#### Step 4: Get AWS Account ID

To find your AWS Account ID:

1. Access: https://console.aws.amazon.com/billing/
2. The Account ID appears in the top right corner
3. Or use the command:
   ```bash
   aws sts get-caller-identity --query Account --output text
   ```

#### Step 5: Test Bucket Access

```bash
# Configure AWS credentials (if not yet configured)
export AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export AWS_REGION="us-east-1"

# Test listing
aws s3 ls s3://YOUR-BUCKET-NAME/

# Test writing
echo "test" > test.txt
aws s3 cp test.txt s3://YOUR-BUCKET-NAME/
rm test.txt

# Test public read (without credentials)
curl https://YOUR-BUCKET-NAME.s3.us-east-1.amazonaws.com/test.txt

# Clean up
aws s3 rm s3://YOUR-BUCKET-NAME/test.txt
```

### 1.4. AWS S3 Monthly Costs

Understanding the monthly costs for maintaining an S3 bucket is important for budgeting. The costs depend on several factors: storage amount, number of requests, and data transfer.

#### Cost Components

**1. Storage Costs (per GB per month)**

- **S3 Standard**: $0.023 per GB/month
- **S3 Standard – Infrequent Access (IA)**: $0.0125 per GB/month
- **S3 One Zone – IA**: $0.01 per GB/month
- **S3 Glacier**: $0.004 per GB/month
- **S3 Glacier Deep Archive**: $0.00099 per GB/month

*Note: Prices shown are for US East (N. Virginia) region (us-east-1). Prices may vary by region.*

**2. Request Costs (per 1,000 requests)**

- **PUT, COPY, POST, LIST requests**: $0.005 per 1,000 requests
- **GET, SELECT, and all other requests**: $0.0004 per 1,000 requests

*Note: These costs apply to S3 Standard. Other storage classes may have different pricing.*

**3. Data Transfer Costs**

- **First 1 GB/month**: Free
- **Next 9.999 TB/month**: $0.09 per GB
- **Next 40 TB/month**: $0.085 per GB
- **Next 100 TB/month**: $0.07 per GB
- **Above 150 TB/month**: $0.05 per GB

*Note: Data transfer between S3 and Amazon EC2 in the same region is free.*

#### Estimated Monthly Cost for Hyperlane Validator

For a typical Hyperlane validator setup, the S3 bucket will store checkpoint signatures. Here's an example calculation:

**Example Scenario:**
- **Storage**: 10 GB of checkpoint signatures
- **PUT requests**: 10,000 requests/month (validator uploading checkpoints)
- **GET requests**: 50,000 requests/month (relayers reading checkpoints)
- **Data transfer**: 5 GB/month (public reads)

**Monthly Cost Breakdown:**

1. **Storage**: 10 GB × $0.023/GB = **$0.23**
2. **PUT requests**: (10,000 / 1,000) × $0.005 = **$0.05**
3. **GET requests**: (50,000 / 1,000) × $0.0004 = **$0.02**
4. **Data transfer**: 
   - First 1 GB: Free
   - Next 4 GB: 4 GB × $0.09/GB = **$0.36**

**Total Estimated Monthly Cost: $0.23 + $0.05 + $0.02 + $0.36 = $0.66/month**

**For a smaller setup (1 GB storage, minimal requests):**
- Storage: 1 GB × $0.023 = $0.023
- Requests: ~$0.01
- Data transfer: ~$0.05
- **Total: ~$0.08 - $0.15/month**

**For a larger setup (100 GB storage, high traffic):**
- Storage: 100 GB × $0.023 = $2.30
- Requests: ~$0.50
- Data transfer: ~$2.00
- **Total: ~$4.80 - $5.50/month**

#### Checkpoint File Size Information

**Average Checkpoint File Size**: ~730 bytes (0.73 KB) per checkpoint file.

This information is useful for estimating storage needs and understanding how many checkpoints can be stored in a given bucket size.

**Calculation: How many checkpoint files to reach 1 GB?**

Using the binary standard (used by operating systems):
- **1 GB = 1,073,741,824 bytes**
- **Checkpoint size**: 730 bytes
- **Files needed**: 1,073,741,824 ÷ 730 ≈ **1,471,564 checkpoint files**

Using the decimal standard (used by storage manufacturers):
- **1 GB = 1,000,000,000 bytes**
- **Checkpoint size**: 730 bytes
- **Files needed**: 1,000,000,000 ÷ 730 ≈ **1,369,863 checkpoint files**

**Quick Reference Table:**

| Storage Size | Checkpoint Files (Binary) | Checkpoint Files (Decimal) | Monthly Cost* |
|--------------|---------------------------|----------------------------|---------------|
| 1 GB         | ~1,471,564 files          | ~1,369,863 files           | $0.023        |
| 5 GB         | ~7,357,820 files          | ~6,849,315 files           | $0.115        |
| 10 GB        | ~14,715,640 files         | ~13,698,630 files          | $0.23         |
| 50 GB        | ~73,578,200 files         | ~68,493,150 files          | $1.15         |
| 100 GB       | ~147,156,400 files        | ~136,986,300 files         | $2.30         |

*Monthly storage cost only (S3 Standard at $0.023/GB). Does not include request or data transfer costs.

**Bash one-liner to calculate checkpoint files for any storage size:**

```bash
# Calculate how many checkpoint files fit in a given GB size
# Usage: ./calc-checkpoints.sh <size_in_gb>
# Example: ./calc-checkpoints.sh 1

cat > calc-checkpoints.sh << 'EOF'
#!/bin/bash

CHECKPOINT_SIZE=730  # bytes
SIZE_GB=${1:-1}

# Binary standard (1 GB = 1,073,741,824 bytes)
GB_BINARY=1073741824
FILES_BINARY=$(echo "scale=0; ($GB_BINARY * $SIZE_GB) / $CHECKPOINT_SIZE" | bc)

# Decimal standard (1 GB = 1,000,000,000 bytes)
GB_DECIMAL=1000000000
FILES_DECIMAL=$(echo "scale=0; ($GB_DECIMAL * $SIZE_GB) / $CHECKPOINT_SIZE" | bc)

# Calculate storage size in bytes
STORAGE_BYTES_BINARY=$(echo "$GB_BINARY * $SIZE_GB" | bc)
STORAGE_BYTES_DECIMAL=$(echo "$GB_DECIMAL * $SIZE_GB" | bc)

# Calculate monthly cost
MONTHLY_COST=$(echo "scale=4; $SIZE_GB * 0.023" | bc)

echo "=========================================="
echo "  Checkpoint Storage Calculator"
echo "=========================================="
echo "Checkpoint file size: ${CHECKPOINT_SIZE} bytes (~0.73 KB)"
echo "Storage size: ${SIZE_GB} GB"
echo ""
echo "Binary Standard (1 GB = 1,073,741,824 bytes):"
echo "  Storage: $(printf "%'d" $STORAGE_BYTES_BINARY) bytes"
echo "  Checkpoint files: ~$(printf "%'d" $FILES_BINARY) files"
echo ""
echo "Decimal Standard (1 GB = 1,000,000,000 bytes):"
echo "  Storage: $(printf "%'d" $STORAGE_BYTES_DECIMAL) bytes"
echo "  Checkpoint files: ~$(printf "%'d" $FILES_DECIMAL) files"
echo ""
echo "Estimated Monthly Storage Cost: \$${MONTHLY_COST}"
echo "=========================================="
EOF

chmod +x calc-checkpoints.sh

# Usage examples:
./calc-checkpoints.sh 1    # Calculate for 1 GB
./calc-checkpoints.sh 10   # Calculate for 10 GB
./calc-checkpoints.sh 100  # Calculate for 100 GB
```

**Example output:**
```
==========================================
  Checkpoint Storage Calculator
==========================================
Checkpoint file size: 730 bytes (~0.73 KB)
Storage size: 1 GB

Binary Standard (1 GB = 1,073,741,824 bytes):
  Storage: 1,073,741,824 bytes
  Checkpoint files: ~1,471,564 files

Decimal Standard (1 GB = 1,000,000,000 bytes):
  Storage: 1,000,000,000 bytes
  Checkpoint files: ~1,369,863 files

Estimated Monthly Storage Cost: $0.0230
==========================================
```

**Calculate from actual bucket usage:**

```bash
# Calculate how many checkpoint files are stored based on actual bucket size
cat > estimate-checkpoints-from-bucket.sh << 'EOF'
#!/bin/bash

BUCKET_NAME="${1}"
CHECKPOINT_SIZE=730  # bytes

if [ -z "$BUCKET_NAME" ]; then
    echo "Usage: $0 <bucket-name>"
    echo "Example: $0 hyperlane-validator-signatures-joao-terraclassic"
    exit 1
fi

# Get bucket size in bytes
SIZE_BYTES=$(aws s3 ls s3://${BUCKET_NAME} --recursive --summarize 2>/dev/null | grep "Total Size" | awk '{print $3}')

if [ -z "$SIZE_BYTES" ] || [ "$SIZE_BYTES" = "0" ]; then
    echo "Bucket is empty or error reading bucket"
    exit 1
fi

# Get object count
OBJECT_COUNT=$(aws s3 ls s3://${BUCKET_NAME} --recursive --summarize 2>/dev/null | grep "Total Objects" | awk '{print $3}')

# Calculate estimated checkpoint files
ESTIMATED_FILES=$(echo "scale=0; $SIZE_BYTES / $CHECKPOINT_SIZE" | bc)
SIZE_GB=$(echo "scale=4; $SIZE_BYTES / 1024 / 1024 / 1024" | bc)
MONTHLY_COST=$(echo "scale=4; $SIZE_GB * 0.023" | bc)

echo "=========================================="
echo "  Checkpoint Estimation from Bucket"
echo "=========================================="
echo "Bucket: ${BUCKET_NAME}"
echo "Actual Objects: $(printf "%'d" $OBJECT_COUNT)"
echo "Total Size: $(printf "%'d" $SIZE_BYTES) bytes ($(printf "%.4f" $SIZE_GB) GB)"
echo ""
echo "Estimated Checkpoint Files: ~$(printf "%'d" $ESTIMATED_FILES) files"
echo "Average File Size: $(echo "scale=2; $SIZE_BYTES / $OBJECT_COUNT" | bc) bytes"
echo ""
echo "Estimated Monthly Storage Cost: \$${MONTHLY_COST}"
echo "=========================================="
EOF

chmod +x estimate-checkpoints-from-bucket.sh

# Usage
./estimate-checkpoints-from-bucket.sh hyperlane-validator-signatures-YOUR-NAME
```

**Note**: The actual checkpoint file size may vary slightly (typically between 724-730 bytes), but 730 bytes is a good average for estimation purposes.

#### Cost Optimization Tips

1. **Use S3 Standard**: For Hyperlane validators, S3 Standard is recommended as checkpoints need frequent access.

2. **Monitor Usage**: Use AWS Cost Explorer to track actual usage:
   ```bash
   # View S3 costs in AWS Console
   # Go to: https://console.aws.amazon.com/cost-management/home
   ```

3. **Set Up Billing Alerts**: Configure CloudWatch alarms to notify you when costs exceed thresholds:
   - Go to: https://console.aws.amazon.com/billing/
   - Set up billing alerts in CloudWatch

4. **Lifecycle Policies**: For long-term storage, consider lifecycle policies to move old checkpoints to cheaper storage classes (if applicable).

5. **Regional Pricing**: Prices vary by region. US East (N. Virginia) typically has the lowest prices.

#### AWS Pricing Calculator

For more accurate cost estimates based on your specific usage:

- **AWS Pricing Calculator**: https://calculator.aws/
- **S3 Pricing Page**: https://aws.amazon.com/s3/pricing/

#### Cost Monitoring

**View current S3 costs:**
```bash
# Using AWS CLI (requires appropriate permissions)
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

**Or via AWS Console:**
1. Go to: https://console.aws.amazon.com/cost-management/home
2. Navigate to **"Cost Explorer"**
3. Filter by service: **"Amazon Simple Storage Service"**

#### Check S3 Bucket Storage Usage

**Quick command to check storage used in your bucket (in MB and GB):**

```bash
# Replace YOUR-BUCKET-NAME with your actual bucket name
BUCKET_NAME="hyperlane-validator-signatures-YOUR-NAME"

# Get total size in bytes, then convert to MB and GB
aws s3 ls s3://${BUCKET_NAME} --recursive --human-readable --summarize | tail -1
```

**Example output:**
```
Total Objects: 1250
   Total Size: 1.2 GiB
```

**More detailed command with MB and GB breakdown:**

```bash
# Replace YOUR-BUCKET-NAME with your actual bucket name
BUCKET_NAME="hyperlane-validator-signatures-YOUR-NAME"

# Get size in bytes
SIZE_BYTES=$(aws s3 ls s3://${BUCKET_NAME} --recursive --summarize | grep "Total Size" | awk '{print $3}')

# Convert to MB and GB
if [ -n "$SIZE_BYTES" ] && [ "$SIZE_BYTES" != "0" ]; then
    SIZE_MB=$(echo "scale=2; $SIZE_BYTES / 1024 / 1024" | bc)
    SIZE_GB=$(echo "scale=2; $SIZE_BYTES / 1024 / 1024 / 1024" | bc)
    
    echo "=========================================="
    echo "  S3 Bucket Storage Usage"
    echo "=========================================="
    echo "Bucket: ${BUCKET_NAME}"
    echo "Size: ${SIZE_BYTES} bytes"
    echo "Size: ${SIZE_MB} MB"
    echo "Size: ${SIZE_GB} GB"
    echo "=========================================="
    
    # Calculate estimated monthly cost
    COST=$(echo "scale=4; $SIZE_GB * 0.023" | bc)
    echo "Estimated Monthly Storage Cost: \$${COST}"
else
    echo "Bucket is empty or error reading bucket"
fi
```

**One-liner command (simplified):**

```bash
# Quick check - shows size in human-readable format
aws s3 ls s3://YOUR-BUCKET-NAME --recursive --summarize | grep "Total Size"
```

**Check storage usage with object count:**

```bash
# Replace YOUR-BUCKET-NAME with your actual bucket name
BUCKET_NAME="hyperlane-validator-signatures-YOUR-NAME"

echo "Checking S3 bucket: ${BUCKET_NAME}"
echo ""

# Get summary
aws s3 ls s3://${BUCKET_NAME} --recursive --summarize | tail -2

# Alternative: Get detailed breakdown
aws s3api list-objects-v2 \
  --bucket ${BUCKET_NAME} \
  --query 'sum(Contents[].Size)' \
  --output text | \
  awk '{
    bytes = $1;
    mb = bytes / 1024 / 1024;
    gb = bytes / 1024 / 1024 / 1024;
    printf "Total Size: %.2f MB (%.4f GB)\n", mb, gb;
  }'
```

**Create a reusable script to check S3 usage:**

```bash
# Create a script to check S3 bucket usage
cat > check-s3-usage.sh << 'EOF'
#!/bin/bash

# Configuration
BUCKET_NAME="${1:-hyperlane-validator-signatures-YOUR-NAME}"

if [ -z "$1" ]; then
    echo "Usage: $0 <bucket-name>"
    echo "Example: $0 hyperlane-validator-signatures-joao-terraclassic"
    exit 1
fi

echo "=========================================="
echo "  S3 Bucket Storage Usage Report"
echo "=========================================="
echo "Bucket: ${BUCKET_NAME}"
echo ""

# Check if bucket exists
if ! aws s3 ls "s3://${BUCKET_NAME}" >/dev/null 2>&1; then
    echo "❌ Error: Bucket '${BUCKET_NAME}' not found or access denied"
    exit 1
fi

# Get summary
SUMMARY=$(aws s3 ls s3://${BUCKET_NAME} --recursive --summarize 2>/dev/null | tail -2)

if [ -z "$SUMMARY" ]; then
    echo "Bucket is empty"
    exit 0
fi

# Extract object count
OBJECT_COUNT=$(echo "$SUMMARY" | grep "Total Objects" | awk '{print $3}')

# Extract total size
TOTAL_SIZE_LINE=$(echo "$SUMMARY" | grep "Total Size")
SIZE_BYTES=$(echo "$TOTAL_SIZE_LINE" | awk '{print $3}')
SIZE_UNIT=$(echo "$TOTAL_SIZE_LINE" | awk '{print $4}')

echo "Total Objects: ${OBJECT_COUNT}"
echo "Total Size: ${SIZE_BYTES} ${SIZE_UNIT}"
echo ""

# Convert to MB and GB if needed
if [ "$SIZE_UNIT" = "bytes" ] || [ "$SIZE_UNIT" = "Byte" ]; then
    SIZE_MB=$(echo "scale=2; $SIZE_BYTES / 1024 / 1024" | bc 2>/dev/null || echo "N/A")
    SIZE_GB=$(echo "scale=4; $SIZE_BYTES / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "N/A")
    
    if [ "$SIZE_MB" != "N/A" ]; then
        echo "Size in MB: ${SIZE_MB} MB"
        echo "Size in GB: ${SIZE_GB} GB"
        echo ""
        
        # Calculate estimated monthly cost (S3 Standard: $0.023 per GB)
        if [ "$SIZE_GB" != "N/A" ]; then
            COST=$(echo "scale=4; $SIZE_GB * 0.023" | bc 2>/dev/null)
            echo "Estimated Monthly Storage Cost: \$${COST}"
            
            # Estimate checkpoint files (assuming ~730 bytes per checkpoint)
            CHECKPOINT_SIZE=730
            ESTIMATED_CHECKPOINTS=$(echo "scale=0; $SIZE_BYTES / $CHECKPOINT_SIZE" | bc 2>/dev/null)
            if [ -n "$ESTIMATED_CHECKPOINTS" ] && [ "$ESTIMATED_CHECKPOINTS" != "0" ]; then
                echo "Estimated Checkpoint Files: ~$(printf "%'d" $ESTIMATED_CHECKPOINTS) files"
            fi
        fi
    fi
elif [ "$SIZE_UNIT" = "KiB" ]; then
    SIZE_MB=$(echo "scale=2; $SIZE_BYTES / 1024" | bc 2>/dev/null || echo "N/A")
    SIZE_GB=$(echo "scale=4; $SIZE_BYTES / 1024 / 1024" | bc 2>/dev/null || echo "N/A")
    echo "Size in MB: ${SIZE_MB} MB"
    echo "Size in GB: ${SIZE_GB} GB"
elif [ "$SIZE_UNIT" = "MiB" ]; then
    SIZE_GB=$(echo "scale=4; $SIZE_BYTES / 1024" | bc 2>/dev/null || echo "N/A")
    echo "Size in GB: ${SIZE_GB} GB"
    COST=$(echo "scale=4; $SIZE_GB * 0.023" | bc 2>/dev/null)
    echo "Estimated Monthly Storage Cost: \$${COST}"
elif [ "$SIZE_UNIT" = "GiB" ]; then
    SIZE_GB=$(echo "scale=4; $SIZE_BYTES" | bc 2>/dev/null || echo "N/A")
    COST=$(echo "scale=4; $SIZE_GB * 0.023" | bc 2>/dev/null)
    echo "Estimated Monthly Storage Cost: \$${COST}"
    
    # Estimate checkpoint files (convert GiB to bytes first)
    if [ "$SIZE_GB" != "N/A" ]; then
        SIZE_BYTES_CALC=$(echo "scale=0; $SIZE_BYTES * 1073741824" | bc 2>/dev/null)
        CHECKPOINT_SIZE=730
        ESTIMATED_CHECKPOINTS=$(echo "scale=0; $SIZE_BYTES_CALC / $CHECKPOINT_SIZE" | bc 2>/dev/null)
        if [ -n "$ESTIMATED_CHECKPOINTS" ] && [ "$ESTIMATED_CHECKPOINTS" != "0" ]; then
            echo "Estimated Checkpoint Files: ~$(printf "%'d" $ESTIMATED_CHECKPOINTS) files"
        fi
    fi
fi

echo "=========================================="
EOF

# Make script executable
chmod +x check-s3-usage.sh

# Usage
./check-s3-usage.sh hyperlane-validator-signatures-YOUR-NAME
```

**Example output of the script:**
```
==========================================
  S3 Bucket Storage Usage Report
==========================================
Bucket: hyperlane-validator-signatures-joao-terraclassic

Total Objects: 1250
Total Size: 1.2 GiB

Size in GB: 1.171875 GB
Estimated Monthly Storage Cost: $0.0269
==========================================
```

**Note**: Make sure you have `bc` installed for calculations:
```bash
# Install bc if not available
sudo apt-get install -y bc
```

#### Important Notes

- ⚠️ **Prices are subject to change**. Always check the official AWS pricing page for the most current rates.
- ⚠️ **Prices vary by region**. The examples above use US East (N. Virginia) pricing.
- ⚠️ **Free Tier**: AWS offers 5 GB of S3 Standard storage, 20,000 GET requests, and 2,000 PUT requests free for the first 12 months for new AWS accounts.
- ⚠️ **Additional costs**: This guide covers S3 costs only. Additional AWS services (IAM, CloudWatch, etc.) may incur minimal additional costs.

**Source**: AWS S3 Pricing Documentation - https://aws.amazon.com/s3/pricing/ (Last updated: 2024)

---

## 2. Private Key Creation in Hex

### 2.1. Terra Classic

Terra Classic uses the Cosmos format (bech32), but the private key is stored in hexadecimal. **Use the `terrad` CLI to generate and manage keys.**

#### Step 1: Install terrad CLI

**Option 1: Binary Download (Recommended)**

```bash
# Download latest terrad binary
TERRA_VERSION="v3.0.1"  # Check the latest version at: https://github.com/classic-terra/core/releases
wget https://github.com/classic-terra/core/releases/download/${TERRA_VERSION}/terrad-${TERRA_VERSION}-linux-amd64
chmod +x terrad-${TERRA_VERSION}-linux-amd64
sudo mv terrad-${TERRA_VERSION}-linux-amd64 /usr/local/bin/terrad

# Verify installation
terrad version
```

**Option 2: Build from Source**

```bash
# Clone repository
git clone https://github.com/classic-terra/core.git
cd core
git checkout v3.0.1
make install

# Verify installation
terrad version
```

#### Step 2: Generate New Private Key

**Option A: Generate New Key (New Wallet)**

```bash
# Generate new key (you will be prompted to enter a password)
terrad keys add validator-key --keyring-backend file

# Or without password prompt (less secure, for testing only)
terrad keys add validator-key --keyring-backend file --no-backup
```

**Example output:**
```
- name: validator-key
  type: local
  address: terra1j0paqg235l7fhjkez8z55kg83snant95jqq0z7
  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"AqBcDeFgHiJkLmNoPqRsTuVwXyZaBcDeFgHiJkLmNoPqRsTuVwXyZa"}'
  mnemonic: ""

**Important write this mnemonic phrase in a safe place.**
It is the only way to recover your account if you ever forget your password.

word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12
word13 word14 word15 word16 word17 word18 word19 word20 word21 word22 word23 word24
```

**⚠️ IMPORTANT**: 
- **Save the mnemonic phrase immediately** - you will need it to recover your key!
- Store in a secure location (password manager, encrypted file, etc.)
- Never share or commit the mnemonic phrase to Git

#### Step 3: Export Private Key in Hexadecimal Format

```bash
# Export private key as hex (you will need the keyring password)
terrad keys export validator-key --keyring-backend file --unarmored-hex --unsafe

# Or save to file
terrad keys export validator-key --keyring-backend file --unarmored-hex --unsafe > ~/.terra-private-key-hex
chmod 600 ~/.terra-private-key-hex
```

**Example output:**
```
abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
```

**Add 0x prefix:**
```bash
# Add 0x prefix
echo "0x$(cat ~/.terra-private-key-hex)" > ~/.terra-private-key
chmod 600 ~/.terra-private-key
```

#### Step 4: Get Terra Classic Address

```bash
# Show address
terrad keys show validator-key --keyring-backend file --address
```

**Example output:**
```
terra1j0paqg235l7fhjkez8z55kg83snant95jqq0z7
```

**Or get complete key information:**
```bash
terrad keys show validator-key --keyring-backend file
```

#### Option B: Import Existing Key

If you already have a Terra Classic private key (hexadecimal format) or mnemonic phrase, you can import it.

**Method 1: Import from Hexadecimal Private Key**

```bash
# Import from hex key (you will be prompted to enter a password)
echo "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890" | terrad keys import validator-key --keyring-backend file

# Or from file
cat ~/.terra-private-key | terrad keys import validator-key --keyring-backend file
```

**Method 2: Import from Mnemonic Phrase**

```bash
# Import from mnemonic (you will be prompted to enter the phrase)
terrad keys add validator-key --recover --keyring-backend file
```

**Exemplo:**
```
> Enter your bip39 mnemonic
word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12 word13 word14 word15 word16 word17 word18 word19 word20 word21 word22 word23 word24

- name: validator-key
  type: local
  address: terra1j0paqg235l7fhjkez8z55kg83snant95jqq0z7
  pubkey: '{"@type":"/cosmos.crypto.secp256k1.PubKey","key":"AqBcDeFgHiJkLmNoPqRsTuVwXyZaBcDeFgHiJkLmNoPqRsTuVwXyZa"}'
```

**Export private key in hex (if needed for config):**
```bash
# Export as hex for use in configuration files
terrad keys export validator-key --keyring-backend file --unarmored-hex --unsafe

# Save to file with 0x prefix
echo "0x$(terrad keys export validator-key --keyring-backend file --unarmored-hex --unsafe)" > ~/.terra-private-key
chmod 600 ~/.terra-private-key
```

#### Step 5: Verify Wallet

```bash
# Show address
terrad keys show validator-key --keyring-backend file --address

# Check balance
curl "https://lcd.terraclassic.community/cosmos/bank/v1beta1/balances/terra1j0paqg235l7fhjkez8z55kg83snant95jqq0z7"
```

**⚠️ IMPORTANT**: 
- Save the private key in a secure location
- Use the Terra address to receive LUNC
- The private key in hex (with `0x` prefix) will be used in JSON configuration files

---

### 2.2. BSC (Binance Smart Chain)

BSC uses the same private key format as Ethereum (ECDSA). **Use `cast` (Foundry) or `openssl` to generate keys via CLI.**

#### Method 1: Using cast (Foundry) - Recommended

**Step 1: Install Foundry**

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
cast --version
```

**Step 2: Generate New Key and Get Address**

```bash
# Generate new key (generates private key and address)
cast wallet new
```

**Example output:**
```
Private Key: 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
Address:     0x8ba1f109551bD432803012645Hac136c22C929E
```

**Step 3: Get Address from Existing Key**

```bash
# Get address from an existing private key
cast wallet address --private-key 0xYOUR_PRIVATE_KEY
```

**Example output:**
```
0x8ba1f109551bD432803012645Hac136c22C929E
```

#### Method 2: Using OpenSSL

```bash
# Generate random private key (32 bytes)
echo "0x$(openssl rand -hex 32)"
```

**Example output:**
```
0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
```

**Get address using cast:**
```bash
# Get address using cast
cast wallet address --private-key 0xYOUR_PRIVATE_KEY
```

**Example output:**
```
Private Key (hex): 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
BSC Address:       0x8ba1f109551bD432803012645Hac136c22C929E
```

**📋 Next steps:**
1. Send BNB to this address
2. Explorer BSC Testnet: https://testnet.bscscan.com/address/YOUR_ADDRESS
3. Explorer BSC Mainnet: https://bscscan.com/address/YOUR_ADDRESS

---

### 2.3. Ethereum (ETH)

Ethereum uses the same private key format as BSC (ECDSA). **Use `cast` (Foundry) or `openssl` to generate keys via CLI.**

#### Method 1: Using cast (Foundry) - Recommended

**Step 1: Install Foundry (if not yet installed)**

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
cast --version
```

**Step 2: Generate New Key and Get Address**

```bash
# Generate new key (generates private key and address)
cast wallet new
```

**Example output:**
```
Private Key: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
Address:     0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0
```

**Step 3: Get Address from Existing Key**

```bash
# Get address from an existing private key
cast wallet address --private-key 0xYOUR_PRIVATE_KEY
```

**Example output:**
```
0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0
```

#### Method 2: Using OpenSSL

```bash
# Generate random private key (32 bytes)
echo "0x$(openssl rand -hex 32)"
```

**Get address using cast:**
```bash
# Get address using cast
cast wallet address --private-key 0xYOUR_PRIVATE_KEY
```

**Example output:**
```
Private Key (hex): 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
Ethereum Address:  0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0
```

**📋 Next steps:**
1. Send ETH to this address
2. Explorer Sepolia Testnet: https://sepolia.etherscan.io/address/YOUR_ADDRESS
3. Explorer Mainnet: https://etherscan.io/address/YOUR_ADDRESS

---

### 2.4. Solana

Solana uses ED25519, which requires a private key of 32 bytes (64 hex characters).

#### Check Existing Solana Keys

**Before generating a new key, check if Solana keys already exist on your machine:**

**Method 1: Check specific file in current directory (quick)**

```bash
# Check if keypair exists in current directory
if [ -f "./solana-keypair.json" ]; then
    echo "✅ Keypair found: ./solana-keypair.json"
    echo "   Address: $(solana-keygen pubkey ./solana-keypair.json 2>/dev/null)"
    
    # Extract private key in hex using repository script
    if [ -f "/home/lunc/hyperlane-validator/get-solana-hexkey.py" ]; then
        echo "   Private Key (hex): $(python3 /home/lunc/hyperlane-validator/get-solana-hexkey.py ./solana-keypair.json 2>/dev/null)"
    else
        # Use Python inline if script does not exist
        echo "   Private Key (hex): $(python3 << 'PYEOF'
import json
try:
    with open('./solana-keypair.json', 'r') as f:
        keypair = json.load(f)
    if isinstance(keypair, list) and len(keypair) == 64:
        private_key_bytes = bytes(keypair[:32])
        print(f"0x{private_key_bytes.hex()}")
except:
    pass
PYEOF
)"
    fi
else
    echo "❌ No keypair found in current directory"
    echo "💡 Execute: solana-keygen new --outfile ./solana-keypair.json"
fi
```

**Method 2: Search for all Solana keypairs on the machine (complete)**

```bash
# Script to list all found Solana keys
cat > list-solana-keys.sh << 'EOF'
#!/bin/bash

echo "============================================================"
echo "  🔍 SEARCHING FOR SOLANA KEYS ON MACHINE"
echo "============================================================"
echo ""

COUNT=0

# Function to check if a file is a valid Solana keypair
check_keypair() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Check if it is valid JSON and has keypair format (array of 64 numbers)
    if command -v jq >/dev/null 2>&1; then
        if jq -e 'type == "array" and length == 64' "$file" >/dev/null 2>&1; then
            # Try to get public address
            local pubkey=$(solana-keygen pubkey "$file" 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$pubkey" ]; then
                COUNT=$((COUNT + 1))
                echo "✅ Keypair #$COUNT found:"
                echo "   File: $file"
                echo "   Address: $pubkey"
                
                # Try to get private key in hex
                if command -v python3 >/dev/null 2>&1; then
                    local hexkey=$(python3 << PYEOF
import json
import sys
try:
    with open("$file", 'r') as f:
        keypair = json.load(f)
    if isinstance(keypair, list) and len(keypair) == 64:
        private_key_bytes = bytes(keypair[:32])
        print(f"0x{private_key_bytes.hex()}")
except:
    pass
PYEOF
)
                    if [ -n "$hexkey" ]; then
                        echo "   Private Key (hex): $hexkey"
                    fi
                fi
                echo ""
                return 0
            fi
        fi
    fi
    return 1
}

# Search in current directory
echo "🔍 Searching in current directory..."
find . -maxdepth 2 -type f -name "*.json" 2>/dev/null | while read file; do
    check_keypair "$file"
done

# Search in common directories
DIRS=(
    "$HOME"
    "$HOME/.config/solana"
    "$HOME/.local/share/solana"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "🔍 Searching in: $dir"
        find "$dir" -maxdepth 3 -type f \( -name "*.json" -o -name "*keypair*" -o -name "*solana*" -o -name "id.json" \) 2>/dev/null | while read file; do
            check_keypair "$file"
        done
    fi
done

if [ $COUNT -eq 0 ]; then
    echo "❌ No Solana keys found."
    echo ""
    echo "💡 To generate a new key, execute:"
    echo "   solana-keygen new --outfile ./solana-keypair.json"
else
    echo "============================================================"
    echo "  ✅ Total keys found: $COUNT"
    echo "============================================================"
fi
EOF

chmod +x list-solana-keys.sh
./list-solana-keys.sh
```

**Method 3: Check Solana CLI default directory**

```bash
# Check if Solana configuration directory exists
if [ -d "$HOME/.config/solana" ]; then
    echo "📁 Solana configuration directory found: $HOME/.config/solana"
    ls -la "$HOME/.config/solana/"
    
    # Check default keypair
    if [ -f "$HOME/.config/solana/id.json" ]; then
        echo ""
        echo "✅ Default keypair found: $HOME/.config/solana/id.json"
        echo "   Address: $(solana-keygen pubkey "$HOME/.config/solana/id.json")"
        
        # Extract private key in hex
        if [ -f "/home/lunc/hyperlane-validator/get-solana-hexkey.py" ]; then
            echo "   Private Key (hex): $(python3 /home/lunc/hyperlane-validator/get-solana-hexkey.py "$HOME/.config/solana/id.json")"
        fi
    fi
else
    echo "❌ Solana configuration directory not found"
fi
```

**Method 4: Quick command to check multiple locations**

```bash
# Check multiple common locations at once
for file in "./solana-keypair.json" "$HOME/.config/solana/id.json" "./id.json"; do
    if [ -f "$file" ]; then
        echo "✅ Keypair found: $file"
        if solana-keygen pubkey "$file" >/dev/null 2>&1; then
            echo "   Address: $(solana-keygen pubkey "$file")"
            if [ -f "/home/lunc/hyperlane-validator/get-solana-hexkey.py" ]; then
                echo "   Private Key (hex): $(python3 /home/lunc/hyperlane-validator/get-solana-hexkey.py "$file")"
            fi
        else
            echo "   ⚠️  Not a valid Solana keypair"
        fi
        echo ""
    fi
done
```

#### Generate New Solana Key (if necessary)

**If no keys were found or you want to generate a new one:**

#### Method 1: Using Solana CLI (Recommended)

```bash
# Install Solana CLI (if not installed)
sh -c "$(curl -sSfL https://release.solana.com/stable/install)"

# Verify installation
solana --version

# Generate new keypair
solana-keygen new --outfile ./solana-keypair.json

# You will be prompted to enter a passphrase (optional but recommended)
# Enter passphrase: [your-passphrase]
# Confirm passphrase: [your-passphrase]
```

**Example output:**
```
Generating a new keypair

For added security, enter a passphrase (empty for no passphrase): 
Wrote new keypair to ./solana-keypair.json

================================================================================
pubkey: 7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU
================================================================================
Save this seed phrase to recover your new keypair:
word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12

================================================================================
```

**⚠️ IMPORTANT**: 
- Save the seed phrase immediately!
- Store in a secure location (password manager, encrypted file, etc.)
- Never share or commit the seed phrase to Git

#### Step 2: Extract Private Key in Hex

**Use repository script (recommended):**

```bash
# Use hyperlane-validator repository script
python3 /home/lunc/hyperlane-validator/get-solana-hexkey.py ./solana-keypair.json
```

**Example output:**
```
0x7c2d098a2870db43d142c87586c62d1252c97aff002176a15d87940d41c79e27
```

**Alternative: Extract manually using CLI commands:**

```bash
# Extract private key using jq and xxd (if available)
# The keypair JSON contains 64 bytes: first 32 are the private key
jq -r '.[:32] | @json' ./solana-keypair.json | jq -r 'map(sprintf "%02x") | join("")' | sed 's/^/0x/'
```

**Or using Python inline (without creating file):**

```bash
python3 << 'EOF'
import json
with open('./solana-keypair.json', 'r') as f:
    keypair = json.load(f)
private_key_bytes = bytes(keypair[:32])
print(f"0x{private_key_bytes.hex()}")
EOF
```

#### Step 3: Get Public Address

```bash
# Get public address
solana-keygen pubkey ./solana-keypair.json

# For testnet
solana-keygen pubkey ./solana-keypair.json --url https://api.testnet.solana.com
```

**Example output:**
```
7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU
```

**⚠️ IMPORTANT**: 
- Solana uses ED25519 (32 bytes)
- The private key must have exactly 64 hex characters (not counting the `0x`)
- Save the private key and seed phrase in a secure location
- The `solana-keypair.json` file contains the complete key - protect it with `chmod 600`

---

## 3. JSON File Configuration

### 3.1. Configure Validator (Terra Classic)

Edit the file `hyperlane/validator.terraclassic.json`:

```bash
cp hyperlane/validator.terraclassic.json.example hyperlane/validator.terraclassic.json
nano hyperlane/validator.terraclassic.json
```

**Configuration:**

```json
{
  "db": "/etc/data/db",
  "checkpointSyncer": {
    "type": "s3",
    "bucket": "hyperlane-validator-signatures-YOUR-NAME",
    "region": "us-east-1"
  },
  "originChainName": "terraclassic",
  "validator": {
    "type": "hexKey",
    "key": "0xYOUR_PRIVATE_KEY_TERRA"
  },
  "chains": {
    "terraclassic": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_PRIVATE_KEY_TERRA",
        "prefix": "terra"
      }
    }
  }
}
```

**⚠️ Replace:**
- `YOUR-NAME` → Your S3 bucket name
- `YOUR_PRIVATE_KEY_TERRA` → Generated private key (without the `0x` in the value, but keep it in JSON)

**Protect file:**
```bash
chmod 600 hyperlane/validator.terraclassic.json
```

### 3.2. Configure Relayer

Edit the file `hyperlane/relayer.json` or `hyperlane/relayer-testnet.json`:

```bash
cp hyperlane/relayer.json.example hyperlane/relayer.json
nano hyperlane/relayer.json
```

**Configuration example (Terra Classic + BSC + Solana):**

```json
{
  "db": "/etc/data/db",
  "relayChains": "terraclassictestnet,bsctestnet,solanatestnet",
  "allowLocalCheckpointSyncers": "false",
  "gasPaymentEnforcement": [{ "type": "none" }],
  "whitelist": [
    {
      "originDomain": [1325],
      "destinationDomain": [97]
    },
    {
      "originDomain": [97],
      "destinationDomain": [1325]
    },
    {
      "originDomain": [1325],
      "destinationDomain": [1399811150]
    },
    {
      "originDomain": [1399811150],
      "destinationDomain": [1325]
    }
  ],
  "chains": {
    "bsctestnet": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_BSC"
      }
    },
    "solanatestnet": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_SOLANA"
      }
    },
    "terraclassictestnet": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_PRIVATE_KEY_TERRA",
        "prefix": "terra"
      }
    }
  }
}
```

**⚠️ Replace:**
- `YOUR_PRIVATE_KEY_BSC` → Generated BSC private key
- `YOUR_PRIVATE_KEY_SOLANA` → Generated Solana private key
- `YOUR_PRIVATE_KEY_TERRA` → Generated Terra Classic private key

**Protect file:**
```bash
chmod 600 hyperlane/relayer.json
```

---

## 4. Verification and Testing

### 4.1. Verify S3 Configuration

```bash
# List objects in bucket
aws s3 ls s3://hyperlane-validator-signatures-YOUR-NAME/ --recursive

# Verify bucket policy
aws s3api get-bucket-policy --bucket hyperlane-validator-signatures-YOUR-NAME

# Test writing
echo "test" > test.txt
aws s3 cp test.txt s3://hyperlane-validator-signatures-YOUR-NAME/
aws s3 rm s3://hyperlane-validator-signatures-YOUR-NAME/test.txt
rm test.txt
```

### 4.2. Verify Private Keys

#### Terra Classic

```bash
# Get address using terrad
terrad keys show validator-key --keyring-backend file --address

# Or if you only have the hex private key, use helper script
python3 /home/lunc/hyperlane-validator/get-address-from-hexkey.py 0xYOUR_PRIVATE_KEY

# Check balance
curl -s "https://lcd.terraclassic.community/cosmos/bank/v1beta1/balances/YOUR_TERRA_ADDRESS" | jq .
```

#### BSC

```bash
# Get address using cast
cast wallet address --private-key 0xYOUR_PRIVATE_KEY

# Check balance (testnet)
curl -s "https://api-testnet.bscscan.com/api?module=account&action=balance&address=YOUR_BSC_ADDRESS&tag=latest" | jq -r '.result' | awk '{print $1/10^18 " BNB"}'

# Check balance (mainnet)
cast balance YOUR_BSC_ADDRESS --rpc-url https://bsc.drpc.org
```

#### Ethereum

```bash
# Get address using cast
cast wallet address --private-key 0xYOUR_PRIVATE_KEY

# Check balance (Sepolia testnet)
curl -s "https://api-sepolia.etherscan.io/api?module=account&action=balance&address=YOUR_ETH_ADDRESS&tag=latest" | jq -r '.result' | awk '{print $1/10^18 " ETH"}'

# Check balance (mainnet)
cast balance YOUR_ETH_ADDRESS --rpc-url https://eth.llamarpc.com
```

#### Solana

```bash
# Verify keypair
solana-keygen verify YOUR_PUBLIC_ADDRESS ./solana-keypair.json

# Get public address
solana-keygen pubkey ./solana-keypair.json

# Check balance (testnet)
solana balance YOUR_PUBLIC_ADDRESS --url https://api.testnet.solana.com

# Check balance (mainnet)
solana balance YOUR_PUBLIC_ADDRESS
```

### 4.3. Test Validator

#### 🚀 Quick Start Commands

##### Testnet Commands

**Start testnet services:**
```bash
docker-compose -f docker-compose-testnet.yml up -d
```

**View testnet logs:**
```bash
# All services
docker-compose -f docker-compose-testnet.yml logs -f

# Specific service
docker-compose -f docker-compose-testnet.yml logs -f relayer
docker-compose -f docker-compose-testnet.yml logs -f validator-terraclassic
```

**Check testnet status:**
```bash
docker-compose -f docker-compose-testnet.yml ps
```

**Stop testnet services:**
```bash
docker-compose -f docker-compose-testnet.yml down
```

**Restart testnet services:**
```bash
docker-compose -f docker-compose-testnet.yml restart
```

##### Production Commands

**Start production services:**
```bash
docker-compose -f docker-compose.yml up -d
```

**View production logs:**
```bash
# All services
docker-compose -f docker-compose.yml logs -f

# Specific service
docker-compose -f docker-compose.yml logs -f relayer
docker-compose -f docker-compose.yml logs -f validator-terraclassic
```

**Check production status:**
```bash
docker-compose -f docker-compose.yml ps
```

**Stop production services:**
```bash
docker-compose -f docker-compose.yml down
```

**Restart production services:**
```bash
docker-compose -f docker-compose.yml restart
```

##### Run Both Simultaneously

Since testnet and production use different ports and volumes, you can run both at the same time:

```bash
# Start both environments
docker-compose -f docker-compose-testnet.yml up -d
docker-compose -f docker-compose.yml up -d

# Check both
docker-compose -f docker-compose-testnet.yml ps
docker-compose -f docker-compose.yml ps

# Stop both
docker-compose -f docker-compose-testnet.yml down
docker-compose -f docker-compose.yml down
```

##### 📝 Key Differences

| Feature | Testnet (`docker-compose-testnet.yml`) | Production (`docker-compose.yml`) |
|---------|----------------------------------------|-----------------------------------|
| **Network** | Testnet | Mainnet |
| **Container Names** | `hpl-relayer-testnet`, `hpl-validator-terraclassic-testnet` | `hpl-relayer`, `hpl-validator-terraclassic` |
| **Config Files** | `agent-config.docker-testnet.json`, `relayer-testnet.json` | `agent-config.docker-mainnet.json`, `relayer-mainnet.json` |
| **Relayer Port** | `9112:9090` | `9110:9090` |
| **Validator Port** | `9122:9090` | `9121:9090` |
| **Relayer Data Volume** | `./relayer-testnet:/etc/data` | `./relayer:/etc/data` |
| **Validator Data Volume** | `./validator-testnet:/etc/data` | `./validator:/etc/data` |
| **Purpose** | Testing and validation | Production deployment |
| **Risk Level** | Low (test tokens) | High (real tokens) |
| **Can Run Simultaneously** | ✅ Yes (different ports & volumes) | ✅ Yes (different ports & volumes) |

##### 🌐 Accessing Services (Ports)

Since testnet and production use different ports, you can run both environments simultaneously:

**Testnet Services:**
- Relayer metrics/API: `http://localhost:9112`
- Validator metrics: `http://localhost:9122`

**Production Services:**
- Relayer metrics/API: `http://localhost:9110`
- Validator metrics: `http://localhost:9121`

**Example: Access testnet relayer metrics:**
```bash
curl http://localhost:9112/metrics
```

**Example: Access production validator metrics:**
```bash
curl http://localhost:9121/metrics
```

##### ✅ Look for Success Messages

When viewing logs, look for these success messages:

**For Validator:**
- `"Successfully announced validator"`
- `"Checkpoint synced to S3"`
- `"Validator running"`

**For Relayer:**
- `"Relayer started"`
- `"Processing messages"`
- `"Message relayed successfully"`

### 4.4. Verify Checkpoints in S3

```bash
# List checkpoints
aws s3 ls s3://hyperlane-validator-signatures-YOUR-NAME/ --recursive

# View last checkpoint
aws s3 ls s3://hyperlane-validator-signatures-YOUR-NAME/ --recursive | tail -1

# Download and view checkpoint
aws s3 cp s3://hyperlane-validator-signatures-YOUR-NAME/checkpoint_0x...json - | jq .
```

---

## 5. Troubleshooting

### 5.1. Error: "AccessDenied" on S3

**Cause**: Incorrect bucket policy or invalid AWS credentials.

**Solution:**
1. Verify bucket policy in AWS Console
2. Verify `.env` file with correct credentials
3. Verify IAM user ARN in policy

```bash
# Verify credentials
aws sts get-caller-identity

# Verify bucket access
aws s3 ls s3://hyperlane-validator-signatures-YOUR-NAME/
```

### 5.2. Error: "Invalid key format"

**Cause**: Private key in incorrect format.

**Solution:**
- Terra Classic/BSC/Ethereum: Key must have 64 hex characters (32 bytes)
- Solana: Key must have 64 hex characters (32 bytes for ED25519)
- All must start with `0x`

```bash
# Verify format
echo "0xYOUR_KEY" | wc -c
# Should return 66 (0x + 64 characters)
```

### 5.3. Error: "Container won't start"

**Cause**: Invalid JSON configuration or missing credentials.

**Solution:**
```bash
# Verify complete logs
docker logs hpl-validator-terraclassic

# Verify JSON
cat hyperlane/validator.terraclassic.json | jq .

# Verify environment variables
docker exec hpl-validator-terraclassic env | grep AWS
```

### 5.4. Error: "Checkpoint not found"

**Cause**: Validator is not writing checkpoints to S3.

**Solution:**
1. Verify `checkpointSyncer` configuration in JSON
2. Verify S3 bucket permissions
3. Verify validator logs

```bash
# Verify configuration
cat hyperlane/validator.terraclassic.json | jq '.checkpointSyncer'

# Verify permissions
aws s3api get-bucket-policy --bucket hyperlane-validator-signatures-YOUR-NAME

# View logs
docker logs hpl-validator-terraclassic | grep -i checkpoint
```

### 5.5. Error: "InvalidSignatureException"

**Cause**: Incorrect private key or address does not match.

**Solution:**
1. Verify if the private key is correct
2. Verify if the address derived from the key is correct
3. Verify if the address has sufficient balance

```bash
# Verify address derived from key
python3 /home/lunc/hyperlane-validator/get-address-from-hexkey.py 0xYOUR_PRIVATE_KEY

# Check balance
# (use the commands from section 4.2)
```

---

## 📚 Additional Resources

- [Hyperlane Documentation](https://docs.hyperlane.xyz/)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [Solana CLI Documentation](https://docs.solana.com/cli)
- [Foundry (cast) Documentation](https://book.getfoundry.sh/reference/cast/)

---

## ✅ Final Checklist

### S3 AWS:
- [ ] IAM user created: `hyperlane-validator`
- [ ] Access Keys created and saved in `.env`
- [ ] IAM permissions configured
- [ ] S3 bucket created
- [ ] Bucket policy configured (public read + IAM write)
- [ ] Bucket access tested

### Private Keys:
- [ ] Terra Classic private key generated
- [ ] Terra Classic address obtained
- [ ] BSC private key generated
- [ ] BSC address obtained
- [ ] Ethereum private key generated
- [ ] Ethereum address obtained
- [ ] Solana private key generated
- [ ] Solana address obtained
- [ ] All keys saved in secure location

### Configuration:
- [ ] `validator.terraclassic.json` configured
- [ ] `relayer.json` configured
- [ ] JSON files protected (chmod 600)
- [ ] JSON files validated (jq)

### Tests:
- [ ] Validator starts without errors
- [ ] Checkpoints appear in S3
- [ ] Relayer reads checkpoints from S3
- [ ] All addresses have sufficient balance

---

**🎉 Configuration complete! Now you are ready to run the Hyperlane validator.**

