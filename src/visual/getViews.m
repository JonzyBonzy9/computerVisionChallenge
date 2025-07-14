function Views = getViews(app)
Views = struct();
Views.Overlay = OverlayView(app);
Views.Difference = DifferenceView3(app);
end