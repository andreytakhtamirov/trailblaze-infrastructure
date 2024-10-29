variable "bucket_name" {
  type        = string
  description = "Bucket containing graphhopper config and data files."
  default     = "trailblaze-graphhopper-bucket"
}

variable "username" {
  type = string
  description = "Host username on GCP instance"
  default = "andreytakht"
}

variable "primary_region" {
  type = string
  description = "Region for system resources"
  default = "us-east5"
}

variable "primary_zone" {
  type = string
  description = "Zone for hosting compute resources"
  default = "us-east5-b"
}
