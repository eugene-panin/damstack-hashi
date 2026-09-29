variable "project" {
  description = "Directory of the project: stack.yaml, and in dns/ the records of the platform and of every app. damstack sets it."
  type        = string
}

variable "state_passphrase" {
  description = "Passphrase the state and plans are encrypted with; kept in vault.yml of the project."
  type        = string
  sensitive   = true
}
