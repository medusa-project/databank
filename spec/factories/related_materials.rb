FactoryBot.define do
  factory :related_material do
    dataset
    material_type { 'Article' }
    availability { 'public' }
    link { 'https://example.org/article' }
    uri { 'https://doi.org/10.1000/example' }
    uri_type { 'DOI' }
    citation { 'Example citation' }
    datacite_list { Databank::Relationship::SUPPLEMENT_TO }
    selected_type { 'Article' }
    note { '' }
    feature { false }
  end
end