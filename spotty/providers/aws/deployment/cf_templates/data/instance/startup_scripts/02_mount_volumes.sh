#!/bin/bash -xe

cfn-signal -e 0 --stack ${AWS::StackName} --region ${AWS::Region} --resource MountingVolumesSignal

# mount volumes
DEVICE_LETTERS=(f g h i j k l m n o p)
MOUNT_DIRS=(${VolumeMountDirectories})

for i in ${!!MOUNT_DIRS[*]}
do
  MOUNT_DIR=${!MOUNT_DIRS[$i]}
  DEVICE=/dev/xvd${!DEVICE_LETTERS[$i]}

  # NVMe EBS volume (see: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nvme-ebs-volumes.html)
  if [ ! -f $DEVICE ]; then
    VOLUME_ID=$(cfn-get-metadata --stack spotty-instance-my-project-i1 --region us-east-2 --resource VolumeAttachment${!DEVICE_LETTERS[$i]^} -k VolumeId)
    DEVICE=$(lsblk -o NAME,SERIAL -dpJ | jq -rc ".blockdevices[] | select(.serial == \"${!VOLUME_ID//-}\") | .name")
    if [ -z "$DEVICE" ]; then
      echo "Device for the volume $VOLUME_ID not found"
      exit 1
    fi
  fi

  blkid -o value -s TYPE $DEVICE || mkfs -t ext4 $DEVICE
  mkdir -p $MOUNT_DIR
  mount $DEVICE $MOUNT_DIR
  resize2fs $DEVICE
done
