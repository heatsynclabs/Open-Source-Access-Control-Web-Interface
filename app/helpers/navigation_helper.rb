# The site header: which links a person sees, and which one is current.
module NavigationHelper
  NavLink = Struct.new(:label, :path, :controllers)

  # The links everyone looks for, in the order of the old site's menu.
  def primary_nav_links
    [
      NavLink.new("Home", root_path, %w[home]),
      NavLink.new("Calendar", calendar_path, %w[calendar]),
      (NavLink.new("People", users_path, %w[users]) if can?(:read, User)),
      (NavLink.new("Tools", resources_path, %w[resources resource_categories]) if can?(:read, Resource)),
      (NavLink.new("Certifications", certifications_path, %w[certifications user_certifications]) if user_signed_in? && can?(:read, Certification)),
      NavLink.new("Computers", macs_path, %w[macs mac_logs]),
    ].compact
  end

  # One menu per role, each holding only the pages the person may use:
  # [[label, [NavLink, ...]], ...]. A role with no pages is left out.
  def role_nav_groups
    analytics = NavLink.new("Analytics", analytics_path, %w[analytics]) if can?(:read, :analytics)
    groups = [
      ["Instructor", [
        (NavLink.new("Sign-offs", user_certifications_path, %w[]) if can?(:create, UserCertification)),
        (NavLink.new("Add member", new_user_path, %w[]) if can?(:create, User)),
      ]],
      ["Treasurer", [
        (NavLink.new("Payments", payments_path, %w[payments]) if can?(:create, Payment)),
        (NavLink.new("PayPal", paypal_csvs_path, %w[paypal_csvs]) if can?(:manage, PaypalCsv)),
        (analytics unless current_user&.admin?),
      ]],
      ["Admin", [
        (NavLink.new("Access cards", cards_path, %w[cards]) if can?(:manage, Card)),
        (NavLink.new("Door log", door_logs_path, %w[door_logs]) if can?(:read, DoorLog)),
        (NavLink.new("Waivers", contracts_path, %w[contracts]) if can?(:read, Contract)),
        (analytics if current_user&.admin?),
        (NavLink.new("Audit log", audit_events_path, %w[audit_events]) if can?(:read, AuditEvent)),
        (NavLink.new("Settings", settings_path, %w[settings]) if can?(:read, Setting)),
      ]],
    ]
    groups.map { |label, links| [label, links.compact] }.reject { |_label, links| links.empty? }
  end

  def nav_current?(link)
    link.controllers.include?(controller_name)
  end

  def nav_link(link)
    current = nav_current?(link)
    link_to link.label, link.path, class: ("on" if current), "aria-current": ("page" if current)
  end

  # The page title: what the view set with content_for(:title), else the
  # section name.
  def page_title
    title = content_for?(:title) ? content_for(:title) : controller_name.humanize
    "#{title} · HeatSync Members"
  end
end
