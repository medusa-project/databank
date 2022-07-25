# app/views/sitemaps/index.xml.builder

xml.instruct! :xml, version: '1.0'
xml.tag! 'sitemapindex', 'xmlns' => "http://www.sitemaps.org/schemas/sitemap/0.9" do

  xml.tag! 'url' do
    xml.tag! 'loc', root_url
  end

  @datasets.each do |dataset|
    xml.tag! 'url' do
      xml.tag! 'loc', dataset_url(dataset)
      xml.lastmod dataset.updated_at.strftime("%F")
    end
  end


end