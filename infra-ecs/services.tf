# per service wiring: image tag source, ports, env maps, sizing, caller sg ids.
# acyclic by design: frontend edges out of the ALB sg, everything else points
# one way, so a single for_each over this map can reference sibling sg ids
locals {
  services = {
    adservice = {
      port        = 9555
      port_name   = "grpc"
      environment = {}
      cpu         = "256"
      memory      = "512"
      callers     = ["frontend"]
      attach_alb  = false
    }
    cartservice = {
      port        = 7070
      port_name   = "grpc"
      environment = {}
      cpu         = "256"
      memory      = "512"
      callers     = ["frontend", "checkoutservice"]
      attach_alb  = false
    }
    checkoutservice = {
      port      = 5050
      port_name = "grpc"
      environment = {
        SHIPPING_SERVICE_ADDR        = "shippingservice.orbit.local:50051"
        PRODUCT_CATALOG_SERVICE_ADDR = "productcatalogservice.orbit.local:3550"
        CART_SERVICE_ADDR            = "cartservice.orbit.local:7070"
        CURRENCY_SERVICE_ADDR        = "currencyservice.orbit.local:7000"
        EMAIL_SERVICE_ADDR           = "emailservice.orbit.local:8082"
        PAYMENT_SERVICE_ADDR         = "paymentservice.orbit.local:50052"
      }
      cpu        = "256"
      memory     = "512"
      callers    = ["frontend"]
      attach_alb = false
    }
    currencyservice = {
      port        = 7000
      port_name   = "grpc"
      environment = {}
      cpu         = "256"
      memory      = "512"
      callers     = ["frontend", "checkoutservice"]
      attach_alb  = false
    }
    emailservice = {
      port      = 8082
      port_name = "grpc"
      environment = {
        # code default is 8080; without this the container binds 8080 while
        # the mapping and discovery register 8082, which blackholes traffic
        PORT = "8082"
      }
      cpu        = "256"
      memory     = "512"
      callers    = ["checkoutservice"]
      attach_alb = false
    }
    frontend = {
      port      = 8080
      port_name = "http"
      environment = {
        PRODUCT_CATALOG_SERVICE_ADDR = "productcatalogservice.orbit.local:3550"
        CURRENCY_SERVICE_ADDR        = "currencyservice.orbit.local:7000"
        CART_SERVICE_ADDR            = "cartservice.orbit.local:7070"
        RECOMMENDATION_SERVICE_ADDR  = "recommendationservice.orbit.local:8081"
        CHECKOUT_SERVICE_ADDR        = "checkoutservice.orbit.local:5050"
        SHIPPING_SERVICE_ADDR        = "shippingservice.orbit.local:50051"
        AD_SERVICE_ADDR              = "adservice.orbit.local:9555"
      }
      cpu        = "512"
      memory     = "1024"
      callers    = []
      attach_alb = true
    }
    loadgenerator = {
      port      = 8080
      port_name = "http"
      environment = {
        FRONTEND_ADDR = "http://frontend.orbit.local:8080"
        USERS         = "10"
        RATE          = "1"
      }
      cpu        = "256"
      memory     = "512"
      callers    = []
      attach_alb = false
    }
    paymentservice = {
      port        = 50052
      port_name   = "grpc"
      environment = {}
      cpu         = "256"
      memory      = "512"
      callers     = ["checkoutservice"]
      attach_alb  = false
    }
    productcatalogservice = {
      port        = 3550
      port_name   = "grpc"
      environment = {}
      cpu         = "256"
      memory      = "512"
      callers     = ["frontend", "checkoutservice", "recommendationservice"]
      attach_alb  = false
    }
    recommendationservice = {
      port      = 8081
      port_name = "grpc"
      environment = {
        # the app refuses to start without the catalog address
        PRODUCT_CATALOG_SERVICE_ADDR = "productcatalogservice.orbit.local:3550"
      }
      cpu        = "256"
      memory     = "512"
      callers    = ["frontend"]
      attach_alb = false
    }
    shippingservice = {
      port        = 50051
      port_name   = "grpc"
      environment = {}
      cpu         = "256"
      memory      = "512"
      callers     = ["frontend", "checkoutservice"]
      attach_alb  = false
    }
  }

  # every service with at least one caller, flattened into one edge per
  # (callee, caller) pair. keys are built from names alone, so they stay
  # known at plan time; sg ids are resolved in the rule resources instead
  caller_edges = merge([
    for svc, cfg in local.services : {
      for caller in cfg.callers : "${caller}->${svc}" => {
        callee = svc
        caller = caller
        port   = cfg.port
      }
    }
  ]...)
}