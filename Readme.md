# Bash script to install AWS Kinesis stream client library

## How to use

1. Copy the installation-script to the device where you want create the Kinesis stream.

1. Give permissions as an executable script.

    ```console
    chmod +x installation-script.sh
    ```

1. Run the script:

    ```console
    ./installation-script.sh -a <aws_account_id> -k <aws_secret_key> -r <aws-region> -n <kinesis-stream-name>
    ```
