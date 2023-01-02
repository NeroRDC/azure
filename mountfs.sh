# This command assumes you have logged in with az login
resourceGroupName="STORAGE-LAB-RG"
storageAccountName="stacca8c7"
fileShareName="labfs"

mntRoot="/mount"
mntPath="$mntRoot/$storageAccountName/$fileShareName"
credentialRoot="$mntRoot/cred"
sudo mkdir -p $mntPath
sudo mkdir $credentialRoot

httpEndpoint=$(az storage account show \
    --resource-group $resourceGroupName \
    --name $storageAccountName \
    --query "primaryEndpoints.file" --output tsv | tr -d '"')
smbPath=$(echo $httpEndpoint | cut -c7-${#httpEndpoint})$fileShareName

storageAccountKey=$(az storage account keys list \
    --resource-group $resourceGroupName \
    --account-name $storageAccountName \
    --query "[0].value" --output tsv | tr -d '"')

# Create the credential file for this individual storage account
smbCredentialFile="$credentialRoot/$storageAccountName.cred"
if [ ! -f $smbCredentialFile ]; then
    echo "username=$storageAccountName" | sudo tee $smbCredentialFile > /dev/null
    echo "password=$storageAccountKey" | sudo tee -a $smbCredentialFile > /dev/null
else
    echo "The credential file $smbCredentialFile already exists, and was not modified."
fi

sudo mount -t cifs $smbPath $mntPath --verbose -o username=$storageAccountName,password=$storageAccountKey,serverino,nosharesock,actimeo=30
if [ -z "$(grep $smbPath\ $mntPath /etc/fstab)" ]; then
    echo "$smbPath $mntPath cifs nofail,credentials=$smbCredentialFile,serverino,nosharesock,actimeo=30" | sudo tee -a /etc/fstab > /dev/null
else
    echo "/etc/fstab was not modified to avoid conflicting entries as this Azure file share was already present. You may want to double check /etc/fstab to ensure the configuration is as desired."
fi
