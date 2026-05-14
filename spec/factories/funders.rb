FactoryBot.define do
  factory :funder do
    dataset
    name { 'National Science Foundation' }
    identifier { '10.13039/100000001' }
    identifier_scheme { 'Crossref Funder ID' }
    grant { 'NSF-12345' }
    code { 'nsf' }
  end
end
