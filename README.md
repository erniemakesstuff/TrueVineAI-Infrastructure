Infrastructure definitions for AI Media Platform (TrueVine AI).

Check syntax of Terraform files.
`terraform validate`
View proposed cloud changes.
`terraform plan`


Cleanup resources:
`terraform state list`
`terraform state rm <resource>`

Notes:
AWS EventBridget to connect DynamoDB CDC to SNS is done manually because creation of source DynamoDB is done progromatically via application startum, not Terraform.
