# hadoop-aws-sdk

Minimal shaded AWS SDK v2 runtime jar (`~16 MiB`) for `hadoop-aws` (S3A) under `/opt/hadoop`.

## Why this exists

Apache's Hadoop 3.4.3 tarball includes `hadoop-aws` and `analyticsaccelerator-s3`, but omits an AWS SDK v2 runtime jar. The upstream `software.amazon.awssdk:bundle` jar is `654 MiB` because it bundles every AWS service. This module shades only the six SDK v2 modules S3A uses (`s3`, `sts`, `kms`, `s3-transfer-manager`, `apache-client`, `netty-nio-client`) with the same `software.amazon.awssdk.thirdparty.*` package relocations as the official bundle.

## Updating and building

- When upgrading Hadoop, match `<aws.sdk.v2.version>` in `pom.xml` to `aws-java-sdk-v2.version` in `hadoop-project-<version>.pom`.
- Build standalone: `mvn -f hadoop-aws-sdk/pom.xml clean package`
- Installed into `/opt/hadoop/hadoop-<version>/share/hadoop/common/lib/` by `scripts/prepare_hadoop.sh`.
