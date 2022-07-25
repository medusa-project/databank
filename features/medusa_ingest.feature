Feature: Medusa Ingest
  In order to preserve datasets from Illinois Data Bank in Medusa
  As an authorized dataset publisher
  I want publication of a dataset to cause it to be ingested into Medusa

  Scenario: Publish
    When I publish a draft dataset
    Then Databank should have sent an ingest request messages to Medusa
