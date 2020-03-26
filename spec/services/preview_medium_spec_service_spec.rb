require "rails_helper"

RSpec.describe PreviewMediumService, type: :service do
  describe "service methods" do
    let(:valid_medium_url) { "https://medium.com/@sfchronicle/why-mark-zuckerberg-should-step-down-as-facebook-ceo-795410ef12eb" }
    let(:invalid_medium_url) { "https://dev.to/nas5w/first-class-functions-in-javascript-5dj2" }
    let(:object) { described_class.call("href" => valid_medium_url) }

    before do
      stub_request(:get, valid_medium_url).
        with(
          headers: {
            "Accept" => "*/*",
            "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
            "User-Agent" => "Ruby"
          },
        ).
        to_return(status: 200, body: "medium", headers: {})
    end

    describe "class_methods" do
      it ".call" do
        expect(object).to be_a described_class
      end
    end

    describe "instance_methods" do
      context "with #call" do
        it "return nil without valid_url" do
          allow(object).to receive(:valid_url?).and_return(false)
          expect(object.call).to be_nil
        end

        it "return nil with invalid response" do
          allow(object).to receive(:send_request).and_return(nil)
          expect(object.call).to be_nil
        end

        it "return object with sucess response" do
          expect(object.call).to be_a described_class
        end
      end

      context "with #valid_url" do
        it "with valid url" do
          expect(object.send(:valid_url?)).to be_truthy
        end

        it "with invalid url" do
          allow(object).to receive(:href).and_return(invalid_medium_url)
          expect(object.send(:valid_url?)).to be_falsy
        end
      end

      context "with #rich_link" do
        it "return with invalid_url" do
          allow(object).to receive(:valid_url?).and_return(false)
          expect(object.rich_link).to eq("")
        end

        it "return with valid_url" do
          expect(object.rich_link).to include("sidecar-medium")
          expect(object.rich_link).to include("chatchannels__richlink")
        end
      end

      it "#create_attributes" do
        response = OpenStruct.new(
          url: valid_medium_url,
          images: ["https://miro.medium.com/max/920/0*x6DKkfEFloE-Lgiw.jpg"],
          title: "Why Mark Zuckerberg Should Step Down as Facebook CEO",
          description: "A shift in the role of CEO Mark Zuckerberg might help address",
        )
        res = object.send(:create_attributes, response)
        expect(res.url).to eq(response.url)
        expect(res.image_url).to eq(response.images[0])
        expect(res.title).to eq(response.title)
        expect(res.description).to eq(response.description)
      end
    end
  end
end
