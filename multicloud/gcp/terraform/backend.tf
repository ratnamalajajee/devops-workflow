terraform {
  backend "gcs" {
    bucket = "shopnow-dev-7k2q-tfstate"
    prefix = "platform"         # locking is built in
  }
}
