terraform {
  backend "gcs" {
    bucket = "nextgen-dev-7k2q-tfstate"
    prefix = "platform"         # locking is built in
  }
}
