json.array!(@datasets) do |dataset|
  if [Databank::PublicationState::RELEASED, Databank::PublicationState::Embargo::FILE, Databank::PublicationState::PermSuppress::FILE].include? dataset.publication_state
    json.extract! dataset, :identifier, :subject, :publication_state, :hold_state, :created_at, :updated_at, :release_date, :plain_text_citation
    json.url dataset_url(dataset, format: :json)
  elsif [Databank::PublicationState::Embargo::METADATA, Databank::PublicationState::DRAFT].include? dataset.publication_state
    json.extract! dataset, :identifier, :publication_state, :hold_state, :created_at, :updated_at
    json.plain_text_citation "unavailable"
    json.url dataset_url(dataset, format: :json)
  end
end
