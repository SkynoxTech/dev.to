class PreviewMediumService
  def initialize(link)
    @href = link["href"]
  end

  def self.call(link)
    new(link).call
  end

  def call
    return unless valid_url?

    response = send_request
    return unless response

    @medium = create_attributes(response)
    self
  end

  def rich_link
    return "" unless valid_url?

    "<a href='#{medium.url}'
      class='chatchannels__richlink'
        target='_blank' data-content='sidecar-medium'>
          #{"<div class='chatchannels__richlinkmainimage' style='background-image:url(" + medium.image_url + ")' data-content='sidecar-medium' ></div>" if medium.image_url.present?}
        <h1 data-content='sidecar-medium'>#{medium.title}</h1>
        <h4 data-content='sidecar-medium'>#{medium.description}</h4>"
  end

  private

  attr_reader :href, :medium

  def valid_url?
    href.include?(ApplicationConfig["MEDIUM_DOMIAN"]) && href.split("/")[4].present?
  end

  def send_request
    OpenGraph.new(href)
  end

  def create_attributes(response)
    OpenStruct.new(
      url: response.url,
      image_url: response.images[0],
      title: response.title,
      description: response.description,
    )
  end
end
