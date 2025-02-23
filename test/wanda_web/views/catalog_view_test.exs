defmodule WandaWeb.CatalogViewTest do
  use WandaWeb.ConnCase, async: true

  import Phoenix.View
  import Wanda.Factory

  describe "CatalogView" do
    test "renders catalog.json" do
      checks = build_list(3, :check)

      assert %{
               items: ^checks
             } = render(WandaWeb.CatalogView, "catalog.json", catalog: checks)
    end
  end
end
