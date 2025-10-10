# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiTest.DocumentStructure do
  @moduledoc """
  https://jsonapi.org/format/#document-structure
  """
  use ExUnit.Case

  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength

  # I'd like to use this as part of a "helper" or "shared example" such that for every single test that has a response from the server - it checks against this, along with our other "manual" tests

  # The official JSON:API schema is as restrictive as possible, but is allowed to be extended (which Ash does).
  # Validation will not yield false negatives, but could yield false positives, which is why there are more tests.
  # See https://jsonapi.org/faq/#is-there-a-json-schema-describing-json-api for details
  # test "it validates against the JSON:API Schema" do
  # url = http://jsonapi.org/schema
  # ExJsonSchema.Validator.validate(json_api_schema, response)
  # return true if :ok
  # return false if :error, and print the error to the screen to help debug
  # {:error, [{"Type mismatch. Expected String but got Integer.", "#/foo"}]}
  # end

  # describe "Top Level" do
  #   test "A JSON object MUST be at the root of every JSON:API request and response containing data" do

  #   end

  #   test "A document MUST contain at least one of the following top-level members: data, errors, meta" do

  #   end

  #   test "The members data and errors MUST NOT coexist in the same document." do

  #   end

  #   test "objects defined by this specification MUST NOT contain any additional members" do

  #   end

  #   test "server implementations MUST ignore members not recognized by this specification." do
  #     # So if a response has data, jsonapi, links, included, and foo - it will be invalid since foo is ignored?
  #     # what about for POST/PATCH requests for the json in the body?
  #   end

  #   test "A document MAY contain any of these top-level members: jsonapi, links, included" do

  #   end

  #   test "If a document does not contain a top-level data key, the included member MUST NOT be present either" do

  #   end

  #   test "The top-level links object MAY contain the following members: self, related, pagination" do

  #   end

  #   describe "for requests that target single resources" do
  #     test "The document’s “primary data” MUST be either: a single resource object, a single resource identifier object, or null" do

  #     end
  #   end

  #   describe "for requests that target resource collections" do
  #     test "The document’s “primary data” MUST be either: an array of resource objects, an array of resource identifier objects, or an empty array ([])" do

  #     end
  #   end

  #   test "A logical collection of resources MUST be represented as an array, even if it only contains one item or is empty." do

  #   end
  # end

  # describe "Resource Objects" do
  #   test "For non-POST requests, a resource object MUST contain at least the following top-level members: id, type" do

  #   end

  #   test "For POST requests, a resource object MUST contain type" do

  #   end

  #   test "a resource object MAY contain any of these top-level members: attributes, relationships, links, meta" do

  #   end

  #   describe "Identification" do
  #     test "Every resource object MUST contain an id member and a type member" do

  #     end

  #     test "The values of the id and type members MUST be strings." do

  #     end

  #     test "Within a given API, each resource object’s type and id pair MUST identify a single, unique resource." do

  #     end

  #     test "The values of type members MUST adhere to the same constraints as member names." do

  #     end

  #     test "inflection rules?" do
  #       # The JSON:API spec is agnostic about inflection rules, so the value of type can be either plural or singular. However, the same value should be used consistently throughout an implementation.
  #     end
  #   end

  #   describe "Fields" do

  #   end

  #   describe "Resource Links" do

  #   end
  # end

  # describe "Resource Identifier Objects" do

  # end

  # describe "Compound Documents" do

  # end

  # describe "Meta Information" do

  # end

  # describe "Links" do
  #   describe "Profile Links" do

  #   end
  # end

  # describe "JSON:API Object" do

  # end

  # describe "Member Names" do
  #   describe "Allowed Characters" do

  #   end

  #   describe "Reserved Characters" do

  #   end

  #   describe "@-Members" do

  #   end
  # end
end
